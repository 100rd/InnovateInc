# ============================================================================
# Resource Quotas
# ============================================================================

resource "kubernetes_resource_quota_v1" "default_namespace" {
  count = var.enable_resource_quotas ? 1 : 0

  metadata {
    name      = "default-quota"
    namespace = "default"
  }

  spec {
    hard = {
      "requests.cpu"    = var.default_namespace_quotas.requests_cpu
      "requests.memory" = var.default_namespace_quotas.requests_memory
      "limits.cpu"      = var.default_namespace_quotas.limits_cpu
      "limits.memory"   = var.default_namespace_quotas.limits_memory
      "pods"            = "100"
    }
  }

  depends_on = [module.eks]
}
