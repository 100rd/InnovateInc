# ============================================================================
# VPC Configuration
# ============================================================================

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.5"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  # Availability zones
  azs = var.azs

  # Subnets
  private_subnets = [for k, v in var.azs : cidrsubnet(var.vpc_cidr, 8, k)]
  public_subnets  = [for k, v in var.azs : cidrsubnet(var.vpc_cidr, 8, k + 4)]

  # NAT Gateway configuration - single NAT for cost optimization
  enable_nat_gateway     = var.enable_nat_gateway
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = false # Explicitly set to false when using single NAT

  # DNS configuration
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  # IPv6 support
  enable_ipv6 = var.enable_ipv6

  # If IPv6 is enabled, create IPv6 CIDR blocks for subnets
  public_subnet_ipv6_prefixes  = var.enable_ipv6 ? [0, 1, 2] : []
  private_subnet_ipv6_prefixes = var.enable_ipv6 ? [3, 4, 5] : []

  # Default security group - restrict default SG
  manage_default_security_group  = true
  default_security_group_name    = "${var.cluster_name}-default"
  default_security_group_ingress = []
  default_security_group_egress  = []

  # Default network ACL
  manage_default_network_acl = true
  default_network_acl_name   = "${var.cluster_name}-default"

  # Default route table
  manage_default_route_table = true
  default_route_table_name   = "${var.cluster_name}-default"

  # Subnet tags for Kubernetes and Load Balancer Controller
  public_subnet_tags = merge(
    local.vpc_public_subnet_tags,
    {
      Module     = "VPC/Public-Subnet"
      SubnetType = "public"
    }
  )

  private_subnet_tags = merge(
    local.vpc_private_subnet_tags,
    {
      Module     = "VPC/Private-Subnet"
      SubnetType = "private"
    }
  )

  # VPC tags
  tags = merge(
    local.common_tags,
    {
      Module = "VPC"
    }
  )

  # IGW tags
  igw_tags = merge(
    local.common_tags,
    {
      Module = "VPC/Internet-Gateway"
    }
  )

  # NAT Gateway tags
  nat_gateway_tags = merge(
    local.common_tags,
    {
      Module = "VPC/NAT-Gateway"
    }
  )

  # NAT EIP tags
  nat_eip_tags = merge(
    local.common_tags,
    {
      Module = "VPC/NAT-EIP"
    }
  )

  # Public route table tags
  public_route_table_tags = merge(
    local.common_tags,
    {
      Module = "VPC/Public-Route-Table"
    }
  )

  # Private route table tags
  private_route_table_tags = merge(
    local.common_tags,
    {
      Module = "VPC/Private-Route-Table"
    }
  )
}

# ============================================================================
# VPC Endpoints (optional for improved security and cost)
# ============================================================================

# S3 Gateway Endpoint - free, improves security
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = module.vpc.vpc_id
  service_name = "com.amazonaws.${var.region}.s3"

  route_table_ids = concat(
    module.vpc.private_route_table_ids,
    module.vpc.public_route_table_ids
  )

  tags = merge(
    local.common_tags,
    {
      Name   = "${var.cluster_name}-s3-endpoint"
      Module = "VPC/Endpoint-S3"
    }
  )
}

# DynamoDB Gateway Endpoint - free, improves security
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = module.vpc.vpc_id
  service_name = "com.amazonaws.${var.region}.dynamodb"

  route_table_ids = concat(
    module.vpc.private_route_table_ids,
    module.vpc.public_route_table_ids
  )

  tags = merge(
    local.common_tags,
    {
      Name   = "${var.cluster_name}-dynamodb-endpoint"
      Module = "VPC/Endpoint-DynamoDB"
    }
  )
}

# ECR API Endpoint - for private ECR access
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = module.vpc.private_subnets

  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(
    local.common_tags,
    {
      Name   = "${var.cluster_name}-ecr-api-endpoint"
      Module = "VPC/Endpoint-ECR-API"
    }
  )
}

# ECR Docker Endpoint - for private ECR access
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = module.vpc.private_subnets

  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(
    local.common_tags,
    {
      Name   = "${var.cluster_name}-ecr-dkr-endpoint"
      Module = "VPC/Endpoint-ECR-DKR"
    }
  )
}

# Security group for VPC endpoints
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.cluster_name}-vpc-endpoints-"
  description = "Security group for VPC endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name   = "${var.cluster_name}-vpc-endpoints"
      Module = "VPC/Security-Group-Endpoints"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}
