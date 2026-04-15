# terraform-aws-infra

Terraform project provisioning AWS EC2 webserver infrastructure across isolated environments, using a reusable module and remote state backend.

## Architecture

```
.
├── bootstrap/          # S3 state bucket + DynamoDB lock table
├── envs/
│   ├── dev/            # Development environment (t3.nano)
│   └── prod/           # Production environment (t3.small)
└── modules/
    └── webserver/      # Reusable EC2 + security group module
```

## What it provisions

Each environment deploys:
- **EC2 instance** — Bitnami Tomcat AMI (latest), configurable instance type
- **Security group** — HTTP (80) and HTTPS (443) inbound, all outbound

## Remote state

State is stored in S3 with DynamoDB locking:
- **Bucket:** `terraform-aws-infra-state-<account-id>` (versioned, encrypted, private)
- **Lock table:** `terraform-aws-infra-locks`
- Each environment has its own isolated state key

## Documentation

- [Onboarding guide](docs/onboarding.md) — setup, workflow, conventions and troubleshooting

## Prerequisites

- Terraform >= 1.0
- AWS credentials configured
- Bootstrap infrastructure deployed (one-time setup)

## Bootstrap (first time only)

```bash
cd bootstrap
terraform init
terraform apply
```

## Usage

Each environment is operated independently:

```bash
# Development
cd envs/dev
terraform init
terraform plan
terraform apply

# Production
cd envs/prod
terraform init
terraform plan
terraform apply
```

## Environments

| Environment | Instance Type | State Key |
|---|---|---|
| dev | `t3.nano` | `envs/dev/terraform.tfstate` |
| prod | `t3.small` | `envs/prod/terraform.tfstate` |

## Key concepts covered

- Provider and Terraform version pinning
- Variables and outputs
- Security groups with `create_before_destroy` lifecycle
- Reusable modules
- Remote state backend (S3 + DynamoDB)
- Isolated environments with shared module
- Custom VPC with public/private subnets across multiple AZs
- IAM instance profile with SSM and CloudWatch agent policies
- Auto Scaling Group + Application Load Balancer
- ACM certificate with DNS validation via Route 53
- CloudWatch alarms and SNS notifications
- GitHub Actions CI/CD with OIDC authentication (no long-lived keys)
