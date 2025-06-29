#!/bin/bash

# Generate SBOM for DunkSense AI Backend
# This script creates Software Bill of Materials for the Go application

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OUTPUT_DIR="./sbom-reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

echo -e "${BLUE}🔍 DunkSense AI - SBOM Generation${NC}"
echo "================================================="

# Check if required tools are installed
check_dependencies() {
    echo -e "${YELLOW}📋 Checking dependencies...${NC}"
    
    local missing_tools=()
    
    if ! command -v syft &> /dev/null; then
        missing_tools+=("syft")
    fi
    
    if ! command -v grype &> /dev/null; then
        missing_tools+=("grype")
    fi
    
    if ! command -v go &> /dev/null; then
        missing_tools+=("go")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo -e "${RED}❌ Missing required tools: ${missing_tools[*]}${NC}"
        echo -e "${YELLOW}Please install the missing tools:${NC}"
        echo "  - Syft: curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin"
        echo "  - Grype: curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin"
        echo "  - Go: https://golang.org/doc/install"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All dependencies found${NC}"
}

# Create output directory
create_output_dir() {
    echo -e "${YELLOW}📁 Creating output directory...${NC}"
    mkdir -p "$OUTPUT_DIR"
    echo -e "${GREEN}✅ Output directory: $OUTPUT_DIR${NC}"
}

# Generate Go module SBOM
generate_go_sbom() {
    echo -e "${YELLOW}🔍 Generating Go module SBOM...${NC}"
    
    # Ensure go.mod is up to date
    go mod download
    go mod verify
    
    # Generate SBOM in multiple formats
    syft packages . \
        -o cyclonedx-json="${OUTPUT_DIR}/sbom-backend-${TIMESTAMP}.json" \
        -o spdx-json="${OUTPUT_DIR}/sbom-backend-spdx-${TIMESTAMP}.json" \
        -o table="${OUTPUT_DIR}/sbom-backend-${TIMESTAMP}.txt" \
        -o syft-json="${OUTPUT_DIR}/sbom-backend-syft-${TIMESTAMP}.json"
    
    echo -e "${GREEN}✅ Go SBOM generated successfully${NC}"
}

# Generate container SBOM (if Docker is available)
generate_container_sbom() {
    if command -v docker &> /dev/null; then
        echo -e "${YELLOW}🐳 Generating container SBOM...${NC}"
        
        # Build temporary image
        docker build -t dunksense-temp:latest -f Dockerfile.metrics-service .
        
        # Generate container SBOM
        syft packages dunksense-temp:latest \
            -o cyclonedx-json="${OUTPUT_DIR}/sbom-container-${TIMESTAMP}.json" \
            -o spdx-json="${OUTPUT_DIR}/sbom-container-spdx-${TIMESTAMP}.json" \
            -o table="${OUTPUT_DIR}/sbom-container-${TIMESTAMP}.txt"
        
        # Clean up temporary image
        docker rmi dunksense-temp:latest
        
        echo -e "${GREEN}✅ Container SBOM generated successfully${NC}"
    else
        echo -e "${YELLOW}⚠️  Docker not found, skipping container SBOM${NC}"
    fi
}

# Run vulnerability scan
run_vulnerability_scan() {
    echo -e "${YELLOW}🛡️  Running vulnerability scan...${NC}"
    
    # Scan the main SBOM file
    local sbom_file="${OUTPUT_DIR}/sbom-backend-${TIMESTAMP}.json"
    
    if [ -f "$sbom_file" ]; then
        # Generate vulnerability report
        grype sbom:"$sbom_file" \
            -o json --file "${OUTPUT_DIR}/vulnerabilities-${TIMESTAMP}.json"
        
        grype sbom:"$sbom_file" \
            -o table --file "${OUTPUT_DIR}/vulnerabilities-${TIMESTAMP}.txt"
        
        grype sbom:"$sbom_file" \
            -o sarif --file "${OUTPUT_DIR}/vulnerabilities-${TIMESTAMP}.sarif"
        
        # Check for critical vulnerabilities
        local critical_count
        critical_count=$(grype sbom:"$sbom_file" -o json | jq '[.matches[] | select(.vulnerability.severity == "Critical")] | length')
        
        local high_count
        high_count=$(grype sbom:"$sbom_file" -o json | jq '[.matches[] | select(.vulnerability.severity == "High")] | length')
        
        echo -e "${BLUE}📊 Vulnerability Summary:${NC}"
        echo -e "   Critical: ${critical_count}"
        echo -e "   High: ${high_count}"
        
        if [ "$critical_count" -gt 0 ]; then
            echo -e "${RED}❌ Critical vulnerabilities found!${NC}"
            return 1
        elif [ "$high_count" -gt 5 ]; then
            echo -e "${YELLOW}⚠️  High number of high-severity vulnerabilities (${high_count})${NC}"
            return 1
        else
            echo -e "${GREEN}✅ Vulnerability scan passed${NC}"
        fi
    else
        echo -e "${RED}❌ SBOM file not found for vulnerability scanning${NC}"
        return 1
    fi
}

# Generate license report
generate_license_report() {
    echo -e "${YELLOW}📜 Generating license report...${NC}"
    
    if command -v go-licenses &> /dev/null; then
        go-licenses report ./... > "${OUTPUT_DIR}/licenses-${TIMESTAMP}.txt" 2>/dev/null || true
        
        # Check for license compliance
        local allowed_licenses="Apache-2.0,BSD-2-Clause,BSD-3-Clause,MIT,ISC"
        if go-licenses check ./... --allowed_licenses="$allowed_licenses" 2>/dev/null; then
            echo -e "${GREEN}✅ License compliance check passed${NC}"
        else
            echo -e "${YELLOW}⚠️  License compliance issues detected${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  go-licenses not found, install with: go install github.com/google/go-licenses@latest${NC}"
    fi
}

# Generate summary report
generate_summary() {
    echo -e "${YELLOW}📋 Generating summary report...${NC}"
    
    local summary_file="${OUTPUT_DIR}/sbom-summary-${TIMESTAMP}.md"
    
    cat > "$summary_file" << EOF
# DunkSense AI - SBOM Report

**Generated**: $(date)
**Timestamp**: ${TIMESTAMP}
**Go Version**: $(go version)

## 📊 Summary

### Generated Files
- \`sbom-backend-${TIMESTAMP}.json\` - CycloneDX SBOM
- \`sbom-backend-spdx-${TIMESTAMP}.json\` - SPDX SBOM
- \`sbom-backend-${TIMESTAMP}.txt\` - Human-readable SBOM
- \`vulnerabilities-${TIMESTAMP}.json\` - Vulnerability report
- \`licenses-${TIMESTAMP}.txt\` - License report

### Dependencies
$(go list -m all | wc -l) total dependencies

### Security Status
- Vulnerability scan: $([ -f "${OUTPUT_DIR}/vulnerabilities-${TIMESTAMP}.json" ] && echo "✅ Completed" || echo "❌ Failed")
- License compliance: $([ -f "${OUTPUT_DIR}/licenses-${TIMESTAMP}.txt" ] && echo "✅ Checked" || echo "⚠️ Skipped")

## 🔗 Next Steps

1. Review vulnerability report for any critical issues
2. Verify license compliance with organizational policies
3. Upload SBOM to dependency tracking system
4. Archive reports for compliance audit trail

---
*Generated by DunkSense AI SBOM Generator*
EOF

    echo -e "${GREEN}✅ Summary report generated: $summary_file${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}Starting SBOM generation process...${NC}"
    
    check_dependencies
    create_output_dir
    generate_go_sbom
    generate_container_sbom
    run_vulnerability_scan
    generate_license_report
    generate_summary
    
    echo -e "${GREEN}🎉 SBOM generation completed successfully!${NC}"
    echo -e "${BLUE}📁 Reports saved to: $OUTPUT_DIR${NC}"
    echo -e "${BLUE}📋 Summary: ${OUTPUT_DIR}/sbom-summary-${TIMESTAMP}.md${NC}"
}

# Run main function
main "$@" 