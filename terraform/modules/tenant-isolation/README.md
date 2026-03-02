# Tenant Isolation Module

Provisions the network foundation for an isolated tenant in a multi-tenant EKS architecture

## What It Creates

- VPC with DNS support
- 6 subnets across 2 AZs (public, private, data)
- Internet Gateway + 2 NAT Gateways
- Route tables (data subnets have no internet route)
- Security groups for EKS nodes, RDS, ALB
- IAM role with permission boundary for tenant-scoped access

## Usage
```hcl
module "tenant_guillen_healthcare" {
  source = "path/to/tenant-isolation"

  tenant_name = "guillen-healthcare"
  environment = "prod"
  vpc_cidr    = "10.1.0.0/16"
  azs         = ["us-east-1a", "us-east-1b"]

  tags = {
    Compliance = "hipaa"
  }
}
```

## Example Plan Output

See [examples/basic/plan_output.txt](examples/basic/plan_output.txt) for sample `terraform plan` output

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| tenant_name | Unique tenant identifier | string | yes |
| environment | Environment name | string | no (default: prod) |
| vpc_cidr | CIDR block for tenant VPC | string | yes |
| azs | List of 2 availability zones | list(string) | yes |
| tags | Additional tags | map(string) | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | Tenant VPC ID |
| private_subnet_ids | Subnet IDs for EKS nodes |
| data_subnet_ids | Subnet IDs for RDS (isolated) |
| eks_nodes_security_group_id | Security group for EKS nodes |
| rds_security_group_id | Security group for RDS |
| tenant_admin_role_arn | IAM role ARN for aws-auth ConfigMap |

