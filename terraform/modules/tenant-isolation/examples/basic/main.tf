# Example: Provision network isolation the Guillen Healthcare Tenant

provider "aws" {
  region = "us-east-1"
}

module "tenant_guillen_healthcare" {
  source = "../../"

  tenant_name = "guillen-healthcare"
  environment = "prod"
  vpc_cidr    = "10.1.0.0/16"
  azs         = ["us-east-1a", "us-east-1b"]

  tags = {
    Project    = "eks-multitenant"
    Owner      = "devops"
    Compliance = "hipaa"
  }
}

output "vpc_id" {
  value = module.tenant_guillen_healthcare.vpc_id
}

output "private_subnet_ids" {
  value = module.tenant_guillen_healthcare.private_subnet_ids
}

output "tenant_admin_role_arn" {
  value = module.tenant_guillen_healthcare.tenant_admin_role_arn
}