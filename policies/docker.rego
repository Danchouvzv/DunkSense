# Docker Security Policies for DunkSense AI
package docker.security

import rego.v1

# Deny running as root user
deny contains msg if {
    input[i].Cmd == "user"
    val := input[i].Value
    val[0] == "root"
    msg := "Container should not run as root user"
}

# Require non-root user
deny contains msg if {
    not has_user_directive
    msg := "Dockerfile must specify a non-root USER directive"
}

has_user_directive if {
    input[_].Cmd == "user"
}

# Deny use of privileged ports
deny contains msg if {
    input[i].Cmd == "expose"
    port := to_number(input[i].Value[0])
    port < 1024
    msg := sprintf("Privileged port %d should not be exposed", [port])
}

# Require specific base images
deny contains msg if {
    input[i].Cmd == "from"
    image := input[i].Value[0]
    not allowed_base_image(image)
    msg := sprintf("Base image %s is not allowed", [image])
}

allowed_base_image(image) if {
    startswith(image, "golang:")
}

allowed_base_image(image) if {
    startswith(image, "alpine:")
}

allowed_base_image(image) if {
    startswith(image, "distroless/")
}

allowed_base_image(image) if {
    startswith(image, "scratch")
}

# Deny ADD instruction (prefer COPY)
deny contains msg if {
    input[i].Cmd == "add"
    msg := "Use COPY instead of ADD for better security"
}

# Require HEALTHCHECK
deny contains msg if {
    not has_healthcheck
    msg := "Dockerfile should include HEALTHCHECK instruction"
}

has_healthcheck if {
    input[_].Cmd == "healthcheck"
}

# Deny curl/wget in RUN instructions
deny contains msg if {
    input[i].Cmd == "run"
    command := input[i].Value[0]
    contains(command, "curl")
    msg := "Avoid using curl in RUN instructions"
}

deny contains msg if {
    input[i].Cmd == "run"
    command := input[i].Value[0]
    contains(command, "wget")
    msg := "Avoid using wget in RUN instructions"
}

# Require specific labels
deny contains msg if {
    not has_required_labels
    msg := "Dockerfile must include required labels: maintainer, version, description"
}

has_required_labels if {
    has_label("maintainer")
    has_label("version")
    has_label("description")
}

has_label(key) if {
    input[i].Cmd == "label"
    some j
    contains(input[i].Value[j], key)
}

# Deny shell form of RUN, CMD, ENTRYPOINT
deny contains msg if {
    input[i].Cmd == "run"
    count(input[i].Value) == 1
    msg := "Use exec form for RUN instructions"
}

deny contains msg if {
    input[i].Cmd == "cmd"
    count(input[i].Value) == 1
    msg := "Use exec form for CMD instructions"
}

deny contains msg if {
    input[i].Cmd == "entrypoint"
    count(input[i].Value) == 1
    msg := "Use exec form for ENTRYPOINT instructions"
}

# Require ARG before FROM for build-time variables
warn contains msg if {
    input[i].Cmd == "from"
    i > 0
    not has_arg_before_from(i)
    msg := "Consider using ARG before FROM for parameterized builds"
}

has_arg_before_from(from_index) if {
    some j
    j < from_index
    input[j].Cmd == "arg"
} 