# terraform-aws-infra

Terraform project provisioning production-grade AWS webserver infrastructure across isolated environments. Features a custom VPC, Auto Scaling Group behind an Application Load Balancer, TLS termination via ACM, Route 53 DNS, CloudWatch observability, and a GitHub Actions CI/CD pipeline with OIDC authentication.

## Architecture

```
.
├── bootstrap/          # One-time setup: S3 state bucket, DynamoDB lock table, GitHub OIDC role
├── envs/
│   ├── dev/            # Development environment (t3.nano, dev.myinfracode.com)
│   └── prod/           # Production environment (t3.small, myinfracode.com)
├── modules/
│   ├── vpc/            # VPC, public/private subnets, IGW, route tables
│   └── webserver/      # ASG, ALB, ACM cert, Route 53, CloudWatch, IAM, key pair
├── .github/
│   └── workflows/      # CI/CD: plan on PR, apply on merge
├── .pre-commit-config.yaml
└── docs/
    └── onboarding.md
```

## What it provisions

Each environment deploys:

| Resource | Details |
|---|---|
| VPC | Custom CIDR, DNS enabled |
| Subnets | 2 public + 2 private across `us-west-2a` and `us-west-2b` |
| Internet Gateway + Route Table | Public subnet internet access |
| Security groups | ALB SG (HTTP/HTTPS from internet), webserver SG (HTTP from ALB only, SSH restricted) |
| Key pair | SSH access using provided public key |
| IAM role + instance profile | SSM Session Manager + CloudWatch agent access |
| Application Load Balancer | Public, multi-AZ, HTTP → HTTPS redirect |
| ACM certificate | DNS-validated TLS certificate |
| Route 53 records | Alias A record + cert validation CNAME |
| Launch Template + ASG | Min 1, max 3 instances across public subnets |
| CloudWatch log group | `/webserver-{env}/application`, 30-day retention |
| CloudWatch alarms | CPU > 80%, unhealthy host count > 0 |
| SNS topic + subscription | Email notifications for alarms |

## Environments

| Environment | Instance Type | Domain | State Key |
|---|---|---|---|
| dev | `t3.nano` | `dev.myinfracode.com` | `envs/dev/terraform.tfstate` |
| prod | `t3.small` | `myinfracode.com` | `envs/prod/terraform.tfstate` |

## Remote state

State is stored in S3 with DynamoDB locking:
- **Bucket:** `terraform-aws-infra-state-<account-id>` (versioned, encrypted, private)
- **Lock table:** `terraform-aws-infra-locks`
- Each environment has its own isolated state key

## CI/CD pipeline

Changes are deployed exclusively through GitHub Actions — no manual `terraform apply` required.

| Trigger | Workflow | Behaviour |
|---|---|---|
| Pull request to `main` | `terraform-plan.yml` | fmt check + validate + plan for dev and prod; posts plan as PR comment |
| Merge to `main` | `terraform-apply.yml` | Auto-applies dev; prod requires manual approval via GitHub environment |

Authentication uses OIDC — no long-lived AWS credentials stored as secrets.

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured
- Bootstrap infrastructure deployed (see below)
- GitHub repository secrets configured (see [Onboarding guide](docs/onboarding.md))

## Bootstrap (first time only)

```bash
cd bootstrap
terraform init
terraform apply -var="github_repo=frnxcode/terraform-aws-infra"
```

This provisions the S3 state bucket, DynamoDB lock table, and the GitHub Actions OIDC IAM role. The role ARN is output and must be added as `AWS_ROLE_ARN` in GitHub repository secrets.

## Local development

For running Terraform locally (outside CI/CD), create a `terraform.tfvars` file in the environment directory — it is gitignored:

```hcl
# envs/dev/terraform.tfvars
public_key       = "ssh-ed25519 AAAA..."
ssh_allowed_cidr = "YOUR_IP/32"
alarm_email      = "you@example.com"
```

Then:

```bash
cd envs/dev
terraform init
terraform plan
terraform apply
```

## Documentation

- [Onboarding guide](docs/onboarding.md) — full setup, workflow, conventions and troubleshooting

## Key concepts

- Custom VPC with isolated public/private subnets across multiple AZs
- Reusable modules with explicit variable contracts
- Remote state backend with S3 + DynamoDB locking
- Isolated environments sharing a common module
- IAM least-privilege with SSM Session Manager (no bastion host needed)
- ALB + ASG for reliability and horizontal scaling
- ACM + Route 53 for TLS termination and DNS management
- CloudWatch alarms with SNS for observability
- GitHub Actions CI/CD with OIDC (no long-lived credentials)
- Pre-commit hooks enforcing format and lint standards
