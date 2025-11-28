# ==================================================
# NGINX Ingress Controller with NLB
# ==================================================

resource "kubernetes_namespace_v1" "ingress_nginx" {
  count = var.enable_nginx_ingress ? 1 : 0

  metadata {
    name = "ingress-nginx"
    labels = {
      name = "ingress-nginx"
    }
  }

  depends_on = [module.eks]
}

resource "helm_release" "nginx_ingress" {
  count = var.enable_nginx_ingress ? 1 : 0

  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = var.nginx_ingress_version
  namespace  = kubernetes_namespace_v1.ingress_nginx[0].metadata[0].name

  values = [
    yamlencode({
      controller = {
        replicaCount = 2
        service = {
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type"                              = "external"
            "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type"                   = "ip"
            "service.beta.kubernetes.io/aws-load-balancer-scheme"                            = var.nginx_nlb_internal ? "internal" : "internet-facing"
            "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
          }
        }
        resources = {
          requests = {
            cpu    = "200m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "1"
            memory = "1Gi"
          }
        }
        metrics = {
          enabled = true
        }
      }
    })
  ]

  depends_on = [module.eks]
}
