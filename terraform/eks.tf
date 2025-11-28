# ============================================================================
# EKS Cluster Configuration
# ============================================================================

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.9"

  name               = var.cluster_name
  kubernetes_version = var.cluster_version

  # Network configuration
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # Cluster endpoint configuration
  endpoint_public_access       = var.cluster_endpoint_public_access
  endpoint_private_access      = var.cluster_endpoint_private_access
  endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  # Encryption configuration
  create_kms_key = var.enable_cluster_encryption
  encryption_config = var.enable_cluster_encryption ? {
    resources = ["secrets"]
  } : {}

  # CloudWatch logging
  enabled_log_types                      = var.cluster_enabled_log_types
  cloudwatch_log_group_retention_in_days = var.cluster_log_retention_days

  # Cluster security group
  additional_security_group_ids = []

  # Node security group
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  # Enable IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  # ============================================================================
  # EKS Access Configuration - CRITICAL for nodes to join cluster
  # ============================================================================

  # Allow cluster creator to have admin permissions
  enable_cluster_creator_admin_permissions = true

  # Authentication mode - use both ConfigMap and API for compatibility
  authentication_mode = "API_AND_CONFIG_MAP"

  # ============================================================================
  # EKS Managed Node Groups
  # ============================================================================

  eks_managed_node_groups = merge(
    # Initial on-demand node group
    {
      initial = {
        name = "initial-nodegroup"

        instance_types = var.node_group_initial_config.instance_types
        capacity_type  = "ON_DEMAND"

        min_size     = var.node_group_initial_config.min_size
        max_size     = var.node_group_initial_config.max_size
        desired_size = var.node_group_initial_config.desired_size

        disk_size       = var.node_group_initial_config.disk_size
        disk_type       = "gp3"
        disk_throughput = 125
        disk_iops       = 3000

        # Enable IMDSv2
        metadata_options = {
          http_endpoint               = "enabled"
          http_tokens                 = "required"
          http_put_response_hop_limit = 2
          instance_metadata_tags      = "enabled"
        }

        # Labels
        labels = {
          Environment  = var.environment
          NodeGroup    = "initial"
          WorkloadType = "general"
        }

        # Taints - none for general workloads
        taints = {}

        # Tags
        tags = merge(
          local.eks_tags,
          {
            Module    = "EKS/NodeGroup-Initial"
            NodeGroup = "initial"
          }
        )
      }
    },
    # Conditional spot instance node group
    var.enable_spot_instances ? {
      spot = {
        name = "spot-nodegroup"

        instance_types = var.node_group_spot_config.instance_types
        capacity_type  = "SPOT"

        min_size     = var.node_group_spot_config.min_size
        max_size     = var.node_group_spot_config.max_size
        desired_size = var.node_group_spot_config.desired_size

        disk_size       = var.node_group_spot_config.disk_size
        disk_type       = "gp3"
        disk_throughput = 125
        disk_iops       = 3000

        # Enable IMDSv2
        metadata_options = {
          http_endpoint               = "enabled"
          http_tokens                 = "required"
          http_put_response_hop_limit = 2
          instance_metadata_tags      = "enabled"
        }

        # Labels
        labels = {
          Environment  = var.environment
          NodeGroup    = "spot"
          WorkloadType = "spot"
          CapacityType = "SPOT"
        }

        # Taint spot nodes so only workloads that tolerate spot run there
        taints = {
          spot = {
            key    = "spot"
            value  = "true"
            effect = "NoSchedule"
          }
        }

        # Tags
        tags = merge(
          local.eks_tags,
          {
            Module    = "EKS/NodeGroup-Spot"
            NodeGroup = "spot"
          }
        )
      }
    } : {}
  )

  # ============================================================================
  # EKS Add-ons
  # ============================================================================

  addons = var.enable_cluster_addons ? {
    # VPC CNI - networking (CRITICAL: Install before node groups)
    vpc-cni = {
      before_compute              = true  # Install BEFORE nodes to prevent NotReady state
      addon_version               = var.addon_versions.vpc_cni
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"

      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION          = "true"
          ENABLE_POD_ENI                    = "true"
          POD_SECURITY_GROUP_ENFORCING_MODE = "standard"
        }
        enableNetworkPolicy = "true"
      })
    }

    # CoreDNS - DNS resolution
    coredns = {
      addon_version               = var.addon_versions.coredns
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"
    }

    # Kube-proxy - networking (Install before node groups for consistency)
    kube-proxy = {
      before_compute              = true  # Install BEFORE nodes
      addon_version               = var.addon_versions.kube_proxy
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"
    }

    # EBS CSI Driver - persistent storage
    aws-ebs-csi-driver = {
      addon_version               = var.addon_versions.aws_ebs_csi_driver
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"

      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  } : {}

  # Tags
  tags = merge(
    local.eks_tags,
    {
      Module = "EKS/Cluster"
    }
  )
}

# ============================================================================
# EKS Access Entries - Allow Karpenter nodes to join
# ============================================================================

resource "aws_eks_access_entry" "karpenter_nodes" {
  count = var.enable_karpenter ? 1 : 0

  cluster_name      = module.eks.cluster_name
  principal_arn     = module.karpenter[0].node_iam_role_arn
  kubernetes_groups = []
  type              = "EC2_LINUX"

  depends_on = [module.eks, module.karpenter]
}

resource "aws_eks_access_policy_association" "karpenter_nodes" {
  count = var.enable_karpenter ? 1 : 0

  cluster_name  = module.eks.cluster_name
  principal_arn = module.karpenter[0].node_iam_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.karpenter_nodes]
}

# ============================================================================
# EBS CSI Driver IRSA Role
# ============================================================================

module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-ebs-csi-driver"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = merge(
    local.common_tags,
    {
      Module = "EKS/IRSA-EBS-CSI"
    }
  )
}

# ============================================================================
# Storage Classes
# ============================================================================

# GP3 storage class (default)
resource "kubernetes_storage_class_v1" "gp3" {
  count = var.enable_cluster_addons ? 1 : 0

  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"

  parameters = {
    type      = "gp3"
    encrypted = "true"
    fsType    = "ext4"
  }

  depends_on = [module.eks]
}

# Remove default gp2 storage class
resource "null_resource" "remove_gp2_default" {
  count = var.enable_cluster_addons ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.region} --kubeconfig /tmp/kubeconfig-${var.cluster_name}
      kubectl --kubeconfig=/tmp/kubeconfig-${var.cluster_name} annotate sc gp2 storageclass.kubernetes.io/is-default-class=false --overwrite || true
      rm -f /tmp/kubeconfig-${var.cluster_name}
    EOT
  }

  depends_on = [module.eks, kubernetes_storage_class_v1.gp3]
}
