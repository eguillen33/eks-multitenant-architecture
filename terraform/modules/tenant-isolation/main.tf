locals {
  name_prefix = "${var.tenant_name}-${var.environment}"

  # Subnet CIDR calculations (using /20 blocks within the /16 VPC)
  public_subnets  = [cidrsubnet(var.vpc_cidr, 4, 0), cidrsubnet(var.vpc_cidr, 4, 1)]
  private_subnets = [cidrsubnet(var.vpc_cidr, 4, 2), cidrsubnet(var.vpc_cidr, 4, 3)]
  data_subnets    = [cidrsubnet(var.vpc_cidr, 4, 4), cidrsubnet(var.vpc_cidr, 4, 5)]

  common_tags = merge(var.tags, {
    Tenant      = var.tenant_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

#--------------------------------------------------------------
# VPC
#--------------------------------------------------------------

resource "aws_vpc" "tenant" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

#--------------------------------------------------------------
# Internet Gateway
#--------------------------------------------------------------

resource "aws_internet_gateway" "tenant" {
  vpc_id = aws_vpc.tenant.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

#--------------------------------------------------------------
# Subnets
#--------------------------------------------------------------

resource "aws_subnet" "public" {
  count                   = length(var.azs)
  vpc_id                  = aws_vpc.tenant.id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-${var.azs[count.index]}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.tenant.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-${var.azs[count.index]}"
    Tier = "private"
  })
}

resource "aws_subnet" "data" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.tenant.id
  cidr_block        = local.data_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-data-${var.azs[count.index]}"
    Tier = "data"
  })
}

#--------------------------------------------------------------
# NAT Gateways (one per AZ for HA)
#--------------------------------------------------------------

resource "aws_eip" "nat" {
  count  = length(var.azs)
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-eip-${var.azs[count.index]}"
  })

  depends_on = [aws_internet_gateway.tenant]
}

resource "aws_nat_gateway" "tenant" {
  count         = length(var.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-${var.azs[count.index]}"
  })

  depends_on = [aws_internet_gateway.tenant]
}

#--------------------------------------------------------------
# Route Tables
#--------------------------------------------------------------

# Public route table - routes to Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.tenant.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tenant.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private route tables - route to NAT Gateway (one per AZ)
resource "aws_route_table" "private" {
  count  = length(var.azs)
  vpc_id = aws_vpc.tenant.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.tenant[count.index].id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-rt-${var.azs[count.index]}"
  })
}

resource "aws_route_table_association" "private" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Data route table - NO internet route (isolated)
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.tenant.id

  # No routes - completely isolated from internet

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-data-rt"
  })
}

resource "aws_route_table_association" "data" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data.id
}

#--------------------------------------------------------------
# Security Groups
#--------------------------------------------------------------

# EKS Nodes security group
resource "aws_security_group" "eks_nodes" {
  name        = "${local.name_prefix}-eks-nodes-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = aws_vpc.tenant.id

  # Allow all egress
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  # Allow nodes to communicate with each other
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow node-to-node communication"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-eks-nodes-sg"
  })
}

# RDS security group
resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Security group for RDS instances"
  vpc_id      = aws_vpc.tenant.id

  # Allow PostgreSQL from EKS nodes only
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
    description     = "Allow PostgreSQL from EKS nodes"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rds-sg"
  })
}

# Load Balancer security group
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.tenant.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS from anywhere"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from anywhere (redirect to HTTPS)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-sg"
  })
}

#--------------------------------------------------------------
# IAM - Tenant Boundary
#--------------------------------------------------------------

# Permission boundary for tenant-scoped IAM roles
resource "aws_iam_policy" "tenant_boundary" {
  name        = "${local.name_prefix}-permission-boundary"
  description = "Permission boundary restricting actions to tenant resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowTenantResourcesOnly"
        Effect = "Allow"
        Action = [
          "ec2:*",
          "eks:*",
          "rds:*",
          "s3:*",
          "logs:*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Tenant" = var.tenant_name
          }
        }
      },
      {
        Sid    = "AllowDescribeActions"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "eks:Describe*",
          "eks:List*",
          "rds:Describe*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

# Tenant admin role (to be mapped in aws-auth ConfigMap)
resource "aws_iam_role" "tenant_admin" {
  name                 = "${local.name_prefix}-admin"
  permissions_boundary = aws_iam_policy.tenant_boundary.arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      }
    ]
  })

  tags = local.common_tags
}

data "aws_caller_identity" "current" {}
