# EKS Multi-Tenant Architecture

Design document and Terraform module for multi-tenant EKS infrastructure with enterprise isolation (assignment exercise)

## Structure
```
├── docs/architecture.md                     # Design document
└── terraform/modules/tenant-isolation/      # Terraform module
```

See [Architecture Design](docs/architecture.md) for the full design document

See [Tenant Isolation Module](terraform/modules/tenant-isolation/README.md) for module details and usage

## Module Choice: Tenant Isolation

Network isolation is the foundation—VPC, subnets, security groups, IAM boundaries. Everything else (EKS, RDS) builds on top of this

## Key Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Isolation model | VPC + EKS per tenant | Namespace isolation insufficient for SOC2/HIPAA compliance |
| AZs | 2 | Redundancy without extra NAT Gateway cost |
| Data subnets | No internet route | Defense in depth for databases |

## With More Time (action items)

- EKS cluster module
- GitHub Actions workflow for tenant provisioning
- Terragrunt for DRY configuration across multiple tenant environments

