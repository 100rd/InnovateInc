# ============================================================================
# Security Hub Integration
# ============================================================================

resource "aws_securityhub_account" "main" {
  count = var.enable_security_hub ? 1 : 0
}

resource "aws_securityhub_standards_subscription" "cis" {
  count         = var.enable_security_hub ? 1 : 0
  standards_arn = "arn:aws:securityhub:${var.region}::standards/cis-aws-foundations-benchmark/v/1.4.0"

  depends_on = [aws_securityhub_account.main]
}

# ============================================================================
# Pod Security Standards
# ============================================================================

resource "kubernetes_labels" "pss_baseline" {
  count = var.enable_pod_security_policy ? 1 : 0

  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = "default"
  }
  labels = {
    "pod-security.kubernetes.io/enforce" = "baseline"
    "pod-security.kubernetes.io/audit"   = "restricted"
    "pod-security.kubernetes.io/warn"    = "restricted"
  }

  depends_on = [module.eks]
}

# ============================================================================
# Falco Runtime Security
# ============================================================================

resource "kubernetes_namespace_v1" "falco" {
  count = var.enable_falco ? 1 : 0

  metadata {
    name = "falco"
  }

  depends_on = [module.eks]
}

resource "helm_release" "falco" {
  count = var.enable_falco ? 1 : 0

  name       = "falco"
  repository = "https://falcosecurity.github.io/charts"
  chart      = "falco"
  version    = var.falco_version
  namespace  = kubernetes_namespace_v1.falco[0].metadata[0].name

  values = [
    yamlencode({
      falco = {
        json_output = true
        log_level   = "info"
      }
      ebpf = {
        enabled = true
      }
    })
  ]

  depends_on = [module.eks]
}
