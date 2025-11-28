# ============================================================================
# Karpenter Autoscaler Configuration
# ============================================================================

module "karpenter" {
  count = var.enable_karpenter ? 1 : 0

  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 21.9"

  cluster_name = module.eks.cluster_name

  # Enable spot instance support
  enable_spot_termination = var.karpenter_enable_spot

  # IRSA configuration
  create_iam_role = true
  iam_role_name   = "eks-karpenter-controller"

  # Node IAM role
  create_node_iam_role = true
  node_iam_role_name   = "eks-karpenter-node"

  tags = merge(
    local.common_tags,
    {
      Module = "EKS/Karpenter-Module"
    }
  )
}

# ============================================================================
# Karpenter Helm Release
# ============================================================================

resource "helm_release" "karpenter" {
  count = var.enable_karpenter ? 1 : 0

  namespace        = "karpenter"
  create_namespace = true

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_version

  values = [
    yamlencode({
      settings = {
        clusterName            = var.cluster_name
        clusterEndpoint        = module.eks.cluster_endpoint
        interruptionQueue      = module.karpenter[0].queue_name
        defaultInstanceProfile = module.karpenter[0].instance_profile_name
      }
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = module.karpenter[0].iam_role_arn
        }
      }
      replicas = 1 # Single replica for free tier (2 = HA but uses 2x resources)
      resources = {
        requests = {
          cpu    = "100m"  # Reduced from 200m for free tier
          memory = "256Mi" # Reduced from 512Mi for free tier
        }
        limits = {
          cpu    = "500m"  # Reduced from 1 CPU
          memory = "512Mi" # Reduced from 1Gi
        }
      }
    })
  ]

  depends_on = [
    module.eks,
    module.karpenter
  ]
}

# ============================================================================
# Karpenter NodePool - General Purpose (x86)
# ============================================================================

resource "kubectl_manifest" "karpenter_node_pool_general" {
  count = var.enable_karpenter ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "general"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            "workload-type" = "general"
            "arch"          = "amd64"
          }
        }
        spec = {
          requirements = concat(
            [
              {
                key      = "kubernetes.io/arch"
                operator = "In"
                values   = ["amd64"]
              },
              {
                key      = "kubernetes.io/os"
                operator = "In"
                values   = ["linux"]
              },
              {
                key      = "karpenter.sh/capacity-type"
                operator = "In"
                values   = var.karpenter_enable_spot ? ["spot", "on-demand"] : ["on-demand"]
              },
              {
                key      = "node.kubernetes.io/instance-type"
                operator = "In"
                values = [
                  "t3.medium", "t3.large", "t3.xlarge",
                  "t3a.medium", "t3a.large", "t3a.xlarge"
                ]
              }
            ]
          )
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "default"
          }
          expireAfter = "720h" # 30 days
        }
      }
      limits = {
        cpu    = tostring(var.karpenter_cpu_limit)
        memory = "${var.karpenter_cpu_limit * 4}Gi"
      }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "1m"
        budgets = [{
          nodes = "10%"
        }]
      }
    }
  })

  depends_on = [helm_release.karpenter]
}

# ============================================================================
# Karpenter NodePool - ARM64 (Graviton)
# ============================================================================

resource "kubectl_manifest" "karpenter_node_pool_arm64" {
  count = var.enable_karpenter ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "arm64"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            "workload-type" = "general"
            "arch"          = "arm64"
          }
        }
        spec = {
          requirements = [
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["arm64"]
            },
            {
              key      = "kubernetes.io/os"
              operator = "In"
              values   = ["linux"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = var.karpenter_enable_spot ? ["spot", "on-demand"] : ["on-demand"]
            },
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "In"
              values = [
                "t4g.medium", "t4g.large", "t4g.xlarge",
                "c7g.medium", "c7g.large", "c7g.xlarge"
              ]
            }
          ]
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "default"
          }
          expireAfter = "720h" # 30 days
        }
      }
      limits = {
        cpu    = tostring(floor(var.karpenter_cpu_limit / 2))
        memory = "${floor(var.karpenter_cpu_limit / 2) * 4}Gi"
      }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "1m"
        budgets = [{
          nodes = "10%"
        }]
      }
    }
  })

  depends_on = [helm_release.karpenter]
}

# ============================================================================
# Karpenter EC2NodeClass
# ============================================================================

resource "kubectl_manifest" "karpenter_node_class" {
  count = var.enable_karpenter ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "default"
    }
    spec = {
      amiFamily = "AL2023" # Amazon Linux 2023
      role      = module.karpenter[0].node_iam_role_name

      subnetSelectorTerms = [{
        tags = {
          "karpenter.sh/discovery" = var.cluster_name
        }
      }]

      securityGroupSelectorTerms = [{
        tags = {
          "karpenter.sh/discovery" = var.cluster_name
        }
      }]

      amiSelectorTerms = [{
        alias = "al2023@latest"
      }]

      blockDeviceMappings = [{
        deviceName = "/dev/xvda"
        ebs = {
          volumeSize          = "50Gi"
          volumeType          = "gp3"
          encrypted           = true
          deleteOnTermination = true
          iops                = 3000
          throughput          = 125
        }
      }]

      userData = base64encode(<<-EOT
        #!/bin/bash
        echo "Karpenter provisioned node"
      EOT
      )

      tags = merge(
        local.eks_tags,
        {
          Name                     = "${var.cluster_name}-karpenter-node"
          Module                   = "EKS/Karpenter-Node"
          "karpenter.sh/discovery" = var.cluster_name
        }
      )

      metadataOptions = {
        httpEndpoint            = "enabled"
        httpProtocolIPv6        = "disabled"
        httpPutResponseHopLimit = 2
        httpTokens              = "required"
      }
    }
  })

  depends_on = [helm_release.karpenter]
}

# ============================================================================
# Security Group Tags for Karpenter Discovery
# ============================================================================

# Tag the cluster security group for Karpenter discovery
resource "aws_ec2_tag" "cluster_sg_karpenter" {
  count = var.enable_karpenter ? 1 : 0

  resource_id = module.eks.cluster_primary_security_group_id
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

# Tag the node security group for Karpenter discovery
resource "aws_ec2_tag" "node_sg_karpenter" {
  count = var.enable_karpenter ? 1 : 0

  resource_id = module.eks.node_security_group_id
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}
