# ==================================================
# External DNS for Route53 Integration
# ==================================================

module "external_dns_irsa" {
  count = var.enable_external_dns ? 1 : 0

  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-external-dns"

  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = var.route53_zone_id != "" ? ["arn:aws:route53:::hostedzone/${var.route53_zone_id}"] : ["arn:aws:route53:::hostedzone/*"]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-dns:external-dns"]
    }
  }

  tags = merge(local.common_tags, { Module = "External-DNS/IRSA" })
}

resource "kubernetes_namespace_v1" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  metadata {
    name = "external-dns"
  }

  depends_on = [module.eks]
}

resource "helm_release" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns"
  chart      = "external-dns"
  version    = var.external_dns_version
  namespace  = kubernetes_namespace_v1.external_dns[0].metadata[0].name

  values = [
    yamlencode({
      serviceAccount = {
        create = true
        name   = "external-dns"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.external_dns_irsa[0].iam_role_arn
        }
      }
      provider      = "aws"
      policy        = "sync"
      domainFilters = length(var.external_dns_domain_filters) > 0 ? var.external_dns_domain_filters : null
      txtOwnerId    = var.cluster_name
    })
  ]

  depends_on = [module.eks, module.external_dns_irsa]
}
