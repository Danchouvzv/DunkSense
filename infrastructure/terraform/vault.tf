# HashiCorp Vault with KMS auto-unseal
resource "aws_kms_key" "vault" {
  description             = "KMS key for Vault auto-unseal"
  deletion_window_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-vault-unseal"
  })
}

resource "aws_kms_alias" "vault" {
  name          = "alias/${local.cluster_name}-vault-unseal"
  target_key_id = aws_kms_key.vault.key_id
}

# IAM role for Vault
resource "aws_iam_role" "vault" {
  name = "${local.cluster_name}-vault-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub": "system:serviceaccount:vault:vault"
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "vault_kms" {
  name = "${local.cluster_name}-vault-kms-policy"
  role = aws_iam_role.vault.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.vault.arn
      }
    ]
  })
}

# Vault Helm release
resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = "0.27.0"
  namespace  = "vault"

  create_namespace = true

  values = [
    <<-EOT
    global:
      enabled: true
      tlsDisable: false

    injector:
      enabled: true
      replicas: 2
      resources:
        requests:
          memory: 256Mi
          cpu: 250m
        limits:
          memory: 256Mi
          cpu: 250m

    server:
      enabled: true
      image:
        repository: "hashicorp/vault"
        tag: "1.15.2"

      resources:
        requests:
          memory: 512Mi
          cpu: 500m
        limits:
          memory: 1Gi
          cpu: 1000m

      readinessProbe:
        enabled: true
        path: "/v1/sys/health?standbyok=true&sealedcode=204&uninitcode=204"
      livenessProbe:
        enabled: true
        path: "/v1/sys/health?standbyok=true"
        initialDelaySeconds: 60

      dataStorage:
        enabled: true
        size: 10Gi
        storageClass: gp3

      auditStorage:
        enabled: true
        size: 10Gi
        storageClass: gp3

      standalone:
        enabled: false

      ha:
        enabled: true
        replicas: 3
        raft:
          enabled: true
          setNodeId: true
          config: |
            ui = true
            
            listener "tcp" {
              tls_disable = 0
              address = "[::]:8200"
              cluster_address = "[::]:8201"
              tls_cert_file = "/vault/userconfig/vault-tls/tls.crt"
              tls_key_file = "/vault/userconfig/vault-tls/tls.key"
            }

            storage "raft" {
              path = "/vault/data"
              
              retry_join {
                leader_api_addr = "https://vault-0.vault-internal:8200"
                leader_ca_cert_file = "/vault/userconfig/vault-tls/ca.crt"
              }
              retry_join {
                leader_api_addr = "https://vault-1.vault-internal:8200"
                leader_ca_cert_file = "/vault/userconfig/vault-tls/ca.crt"
              }
              retry_join {
                leader_api_addr = "https://vault-2.vault-internal:8200"
                leader_ca_cert_file = "/vault/userconfig/vault-tls/ca.crt"
              }
            }

            seal "awskms" {
              region     = "${var.aws_region}"
              kms_key_id = "${aws_kms_key.vault.key_id}"
            }

            service_registration "kubernetes" {}

      serviceAccount:
        create: true
        name: vault
        annotations:
          eks.amazonaws.com/role-arn: ${aws_iam_role.vault.arn}

    ui:
      enabled: true
      serviceType: "ClusterIP"
    EOT
  ]

  depends_on = [aws_iam_role_policy.vault_kms]
}

# Vault secret rotation CronJob
resource "kubectl_manifest" "vault_rotation_cronjob" {
  yaml_body = <<-YAML
    apiVersion: batch/v1
    kind: CronJob
    metadata:
      name: vault-secret-rotation
      namespace: vault
    spec:
      schedule: "0 2 * * 0"  # Weekly on Sunday at 2 AM
      jobTemplate:
        spec:
          template:
            spec:
              serviceAccountName: vault-rotation
              containers:
              - name: rotation
                image: hashicorp/vault:1.15.2
                command:
                - /bin/sh
                - -c
                - |
                  # Set Vault address
                  export VAULT_ADDR=https://vault:8200
                  export VAULT_CACERT=/vault/userconfig/vault-tls/ca.crt
                  
                  # Authenticate using Kubernetes auth
                  vault auth -method=kubernetes role=rotation
                  
                  # Rotate database credentials
                  vault write -force database/rotate-role/postgres-role
                  vault write -force database/rotate-role/redis-role
                  
                  # Rotate API keys (if configured)
                  vault write -force sys/rotate
                  
                  echo "Secret rotation completed successfully"
                env:
                - name: VAULT_TOKEN
                  valueFrom:
                    secretKeyRef:
                      name: vault-rotation-token
                      key: token
                volumeMounts:
                - name: vault-tls
                  mountPath: /vault/userconfig/vault-tls
                  readOnly: true
              volumes:
              - name: vault-tls
                secret:
                  secretName: vault-tls
              restartPolicy: OnFailure
  YAML

  depends_on = [helm_release.vault]
}

# Service account for rotation job
resource "kubectl_manifest" "vault_rotation_sa" {
  yaml_body = <<-YAML
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: vault-rotation
      namespace: vault
      annotations:
        eks.amazonaws.com/role-arn: ${aws_iam_role.vault.arn}
  YAML
}

# Vault database secrets engine configuration
resource "kubectl_manifest" "vault_database_config" {
  yaml_body = <<-YAML
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: vault-database-config
      namespace: vault
    data:
      init.sh: |
        #!/bin/bash
        set -e
        
        # Wait for Vault to be ready
        until vault status; do
          echo "Waiting for Vault..."
          sleep 5
        done
        
        # Enable database secrets engine
        vault secrets enable -path=database database
        
        # Configure PostgreSQL connection
        vault write database/config/postgres-db \
          plugin_name=postgresql-database-plugin \
          connection_url="postgresql://{{username}}:{{password}}@${aws_db_instance.main.endpoint}/{{database}}?sslmode=require" \
          allowed_roles="postgres-role" \
          username="${var.db_username}" \
          password="${var.db_password}"
        
        # Create PostgreSQL role
        vault write database/roles/postgres-role \
          db_name=postgres-db \
          creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
          default_ttl="1h" \
          max_ttl="24h"
        
        # Configure Redis (if needed)
        echo "Database secrets engine configured successfully"
  YAML

  depends_on = [helm_release.vault]
} 