# ============================================================================
# Local Variables and Common Tags
# ============================================================================

locals {
  # Common tags to be applied to all resources
  common_tags = {
    Environment = var.environment
    Project     = var.project
    Owner       = var.owner
    Ticket      = var.ticket
    CostCenter  = var.cost_center
    ManagedBy   = "Terraform"
    Repository  = "opsfleet/terraform"
  }

  # EKS-specific tags
  eks_tags = merge(local.common_tags, {
    "karpenter.sh/discovery" = var.cluster_name
  })

  # VPC tags for Kubernetes integration
  vpc_public_subnet_tags = merge(local.common_tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  })

  vpc_private_subnet_tags = merge(local.common_tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
    "karpenter.sh/discovery"                    = var.cluster_name
  })

  # Generate unique bucket name with account ID
  state_bucket_name = "${var.state_bucket_prefix}-${data.aws_caller_identity.current.account_id}"

  # Cluster security group tags for Karpenter
  cluster_sg_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Data source to get current AWS region
data "aws_region" "current" {}
