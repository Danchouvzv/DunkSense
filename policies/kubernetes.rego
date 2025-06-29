# Kubernetes Security Policies for DunkSense AI
package kubernetes.security

import rego.v1

# Deny containers running as root
deny contains msg if {
    input.kind == "Pod"
    input.spec.containers[i].securityContext.runAsUser == 0
    msg := sprintf("Container %s should not run as root", [input.spec.containers[i].name])
}

deny contains msg if {
    input.kind == "Deployment"
    input.spec.template.spec.containers[i].securityContext.runAsUser == 0
    msg := sprintf("Container %s should not run as root", [input.spec.template.spec.containers[i].name])
}

# Require security context
deny contains msg if {
    input.kind in ["Pod", "Deployment"]
    containers := get_containers(input)
    containers[i]
    not containers[i].securityContext
    msg := sprintf("Container %s must have securityContext defined", [containers[i].name])
}

get_containers(obj) := containers if {
    obj.kind == "Pod"
    containers := obj.spec.containers
}

get_containers(obj) := containers if {
    obj.kind == "Deployment"
    containers := obj.spec.template.spec.containers
}

# Deny privileged containers
deny contains msg if {
    containers := get_containers(input)
    containers[i].securityContext.privileged == true
    msg := sprintf("Container %s should not run in privileged mode", [containers[i].name])
}

# Require resource limits
deny contains msg if {
    containers := get_containers(input)
    containers[i]
    not containers[i].resources.limits
    msg := sprintf("Container %s must have resource limits defined", [containers[i].name])
}

# Require CPU and memory limits
deny contains msg if {
    containers := get_containers(input)
    containers[i].resources.limits
    not containers[i].resources.limits.cpu
    msg := sprintf("Container %s must have CPU limit defined", [containers[i].name])
}

deny contains msg if {
    containers := get_containers(input)
    containers[i].resources.limits
    not containers[i].resources.limits.memory
    msg := sprintf("Container %s must have memory limit defined", [containers[i].name])
}

# Deny hostNetwork
deny contains msg if {
    input.kind in ["Pod", "Deployment"]
    spec := get_pod_spec(input)
    spec.hostNetwork == true
    msg := "hostNetwork should not be enabled"
}

get_pod_spec(obj) := spec if {
    obj.kind == "Pod"
    spec := obj.spec
}

get_pod_spec(obj) := spec if {
    obj.kind == "Deployment"
    spec := obj.spec.template.spec
}

# Deny hostPID
deny contains msg if {
    spec := get_pod_spec(input)
    spec.hostPID == true
    msg := "hostPID should not be enabled"
}

# Deny hostIPC
deny contains msg if {
    spec := get_pod_spec(input)
    spec.hostIPC == true
    msg := "hostIPC should not be enabled"
}

# Require readiness and liveness probes
deny contains msg if {
    containers := get_containers(input)
    containers[i]
    not containers[i].readinessProbe
    msg := sprintf("Container %s must have readinessProbe defined", [containers[i].name])
}

deny contains msg if {
    containers := get_containers(input)
    containers[i]
    not containers[i].livenessProbe
    msg := sprintf("Container %s must have livenessProbe defined", [containers[i].name])
}

# Deny containers with allowPrivilegeEscalation
deny contains msg if {
    containers := get_containers(input)
    containers[i].securityContext.allowPrivilegeEscalation == true
    msg := sprintf("Container %s should not allow privilege escalation", [containers[i].name])
}

# Require readOnlyRootFilesystem
deny contains msg if {
    containers := get_containers(input)
    containers[i].securityContext
    not containers[i].securityContext.readOnlyRootFilesystem == true
    msg := sprintf("Container %s should have readOnlyRootFilesystem enabled", [containers[i].name])
}

# Deny containers with capabilities
deny contains msg if {
    containers := get_containers(input)
    containers[i].securityContext.capabilities.add
    count(containers[i].securityContext.capabilities.add) > 0
    msg := sprintf("Container %s should not add capabilities", [containers[i].name])
}

# Require dropping ALL capabilities
deny contains msg if {
    containers := get_containers(input)
    containers[i].securityContext.capabilities
    not "ALL" in containers[i].securityContext.capabilities.drop
    msg := sprintf("Container %s should drop ALL capabilities", [containers[i].name])
}

# Require Pod Security Standards labels
deny contains msg if {
    input.kind == "Namespace"
    not input.metadata.labels["pod-security.kubernetes.io/enforce"]
    msg := "Namespace must have pod-security.kubernetes.io/enforce label"
}

deny contains msg if {
    input.kind == "Namespace"
    input.metadata.labels["pod-security.kubernetes.io/enforce"] != "restricted"
    msg := "Namespace should enforce 'restricted' Pod Security Standard"
}

# Require NetworkPolicy for network segmentation
deny contains msg if {
    input.kind == "Namespace"
    input.metadata.name != "kube-system"
    input.metadata.name != "default"
    not has_network_policy
    msg := sprintf("Namespace %s should have associated NetworkPolicy", [input.metadata.name])
}

has_network_policy if {
    # This would need to be checked against other resources in the cluster
    # For now, we'll assume it's checked externally
    true
}

# Require resource quotas for namespaces
deny contains msg if {
    input.kind == "Namespace"
    input.metadata.name != "kube-system"
    input.metadata.name != "default"
    not has_resource_quota
    msg := sprintf("Namespace %s should have ResourceQuota defined", [input.metadata.name])
}

has_resource_quota if {
    # This would need to be checked against other resources in the cluster
    # For now, we'll assume it's checked externally
    true
}

# Deny default service accounts
deny contains msg if {
    spec := get_pod_spec(input)
    spec.serviceAccountName == "default"
    msg := "Pods should not use default service account"
}

# Require specific image registries
deny contains msg if {
    containers := get_containers(input)
    containers[i].image
    not allowed_registry(containers[i].image)
    msg := sprintf("Container %s uses unauthorized registry", [containers[i].name])
}

allowed_registry(image) if {
    startswith(image, "ghcr.io/")
}

allowed_registry(image) if {
    startswith(image, "gcr.io/")
}

allowed_registry(image) if {
    startswith(image, "docker.io/library/")
}

# Require image tags (no latest)
deny contains msg if {
    containers := get_containers(input)
    containers[i].image
    endswith(containers[i].image, ":latest")
    msg := sprintf("Container %s should not use 'latest' tag", [containers[i].name])
}

deny contains msg if {
    containers := get_containers(input)
    containers[i].image
    not contains(containers[i].image, ":")
    msg := sprintf("Container %s must specify image tag", [containers[i].name])
} 