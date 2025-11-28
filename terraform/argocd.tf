# ============================================================================
# ArgoCD GitOps Platform
# ============================================================================

resource "kubernetes_namespace_v1" "argocd" {
  count = var.enable_argocd ? 1 : 0

  metadata {
    name = "argocd"
  }

  depends_on = [module.eks]
}

resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0

  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version
  namespace  = kubernetes_namespace_v1.argocd[0].metadata[0].name

  values = [
    yamlencode({
      global = {
        domain = "argocd.${var.cluster_name}.local"
      }
      server = {
        replicas = 2
        service = {
          type = "LoadBalancer"
        }
      }
      controller = {
        replicas = 2
      }
      repoServer = {
        replicas = 2
      }
    })
  ]

  depends_on = [module.eks]
}
