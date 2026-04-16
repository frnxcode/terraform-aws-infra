# Onboarding Guide — terraform-aws-infra

This guide walks you through everything you need to understand, work with, and contribute to this project.

---

## What is this project?

`terraform-aws-infra` provisions production-grade AWS infrastructure using Terraform. It deploys a full 3-tier architecture — load balancer, compute, and database — across isolated `dev` and `prod` environments, with security (WAF, private subnets), observability (VPC Flow Logs, CloudWatch), and auto scaling built in. Changes are deployed exclusively through a GitHub Actions CI/CD pipeline.

---

## Prerequisites

| Tool | Purpose | Install |
|---|---|---|
| Terraform >= 1.0 | Infrastructure provisioning | [terraform.io](https://developer.hashicorp.com/terraform/install) |
| AWS CLI | AWS authentication and querying | [aws.amazon.com/cli](https://aws.amazon.com/cli/) |
| Git | Version control | [git-scm.com](https://git-scm.com) |
| pre-commit | Git hook runner | `brew install pre-commit` |
| tflint | Terraform linter | `brew install tflint` |

### AWS credentials

```bash
aws configure
# Region: us-west-2
# Output: json
```

### Pre-commit hooks

```bash
pre-commit install
```

Enforces `terraform fmt`, `terraform validate`, and `tflint` on every commit.

---

## Repository structure

```
terraform-aws-infra/
├── bootstrap/                  # One-time setup: state backend + GitHub OIDC role
├── envs/
│   ├── dev/                    # Development environment (t3.nano, dev.myinfracode.com)
│   └── prod/                   # Production environment (t3.small, myinfracode.com)
├── modules/
│   ├── vpc/                    # VPC, subnets, IGW, NAT Gateway, route tables, VPC Flow Logs
│   ├── webserver/              # ASG, ALB, ACM, Route 53, IAM, CloudWatch, Auto Scaling policies
│   ├── rds/                    # RDS PostgreSQL, DB subnet group, security group, Secrets Manager
│   └── waf/                    # WAF v2 Web ACL, managed rule groups, CloudWatch logging
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml  # Runs on PR: fmt + validate + plan
│       └── terraform-apply.yml # Runs on merge: apply dev, then prod with approval
├── .pre-commit-config.yaml
├── .tflint.hcl
└── docs/
    └── onboarding.md
```

---

## Core concepts

### VPC module

Each environment gets its own isolated VPC:

| Layer | Subnets | What lives here |
|---|---|---|
| Public | `us-west-2a`, `us-west-2b` | ALB, NAT Gateway |
| Private | `us-west-2a`, `us-west-2b` | EC2 instances, RDS |

- Public subnets route to the Internet Gateway
- Private subnets route to the NAT Gateway (outbound only)
- VPC Flow Logs capture all traffic to CloudWatch (`/{env}/vpc/flow-logs`)

| Environment | VPC CIDR | Public subnets | Private subnets |
|---|---|---|---|
| dev | `10.0.0.0/16` | `10.0.1.0/24`, `10.0.2.0/24` | `10.0.101.0/24`, `10.0.102.0/24` |
| prod | `10.1.0.0/16` | `10.1.1.0/24`, `10.1.2.0/24` | `10.1.101.0/24`, `10.1.102.0/24` |

### Webserver module

- **IAM role** — grants SSM Session Manager, CloudWatch agent, and Secrets Manager access
- **Security groups** — ALB accepts HTTP/HTTPS from internet; EC2 accepts HTTP from ALB only
- **ALB** — public, multi-AZ, HTTP redirects to HTTPS
- **ACM certificate** — DNS-validated TLS
- **Route 53** — alias A record (ALB) + CNAME (cert validation)
- **Launch Template + ASG** — EC2 instances in private subnets, no public IPs
- **Auto Scaling policies** — CPU target tracking (50%) and ALB request count (1 000 req/target)
- **CloudWatch alarms** — CPU > 80% and unhealthy host count > 0, notified via SNS

### RDS module

- PostgreSQL 16 in private subnets, encrypted at rest, no public access
- DB subnet group spans both private subnets
- Security group allows port 5432 from the webserver security group only
- Credentials auto-generated and stored in Secrets Manager as JSON (`/{env}/rds/app`)
- EC2 IAM role granted `secretsmanager:GetSecretValue` scoped to that one secret ARN

### WAF module

Web ACL attached to the ALB with three AWS managed rule groups:

| Priority | Rule group | Blocks |
|---|---|---|
| 10 | IP Reputation List | Known malicious IPs, botnets |
| 20 | Core Rule Set | SQLi, XSS, path traversal |
| 30 | Known Bad Inputs | Log4Shell, Spring4Shell, SSRF |

WAF decisions logged to `aws-waf-logs-{env}` in CloudWatch.

### Remote state

| Environment | State key |
|---|---|
| dev | `envs/dev/terraform.tfstate` |
| prod | `envs/prod/terraform.tfstate` |

- Bucket: `terraform-aws-infra-state-<account-id>` (versioned, encrypted, public access blocked)
- Lock table: `terraform-aws-infra-locks`

### CI/CD pipeline

1. **Open a PR** → fmt check, validate, and plan for both environments; plan posted as PR comment
2. **Merge to main** → dev applies automatically; prod requires manual approval via GitHub environment

GitHub Actions authenticates to AWS via OIDC — no long-lived credentials stored anywhere.

---

## First-time setup (bootstrap)

Run once per AWS account:

```bash
cd bootstrap
terraform init
terraform apply -var="github_repo=frnxcode/terraform-aws-infra"
```

Copy the `github_actions_role_arn` from the output.

### GitHub repository secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Value |
|---|---|
| `AWS_ROLE_ARN` | Role ARN from bootstrap output |
| `TF_VAR_PUBLIC_KEY` | Your SSH public key (`cat ~/.ssh/id_ed25519_francis_mac.pub`) |
| `TF_VAR_ALARM_EMAIL` | Email address for CloudWatch alarm notifications |

### GitHub environments

Go to **Settings → Environments** and create:
- `dev` — no protection rules (applies automatically on merge)
- `prod` — add yourself as a required reviewer (gates the prod apply)

---

## Day-to-day workflow

### Making a change

1. Create a feature branch
2. Make your changes
3. Open a pull request to `main`
4. Review the plan output posted as a PR comment
5. Merge — dev applies automatically, approve prod when ready

### Local development

Create a `terraform.tfvars` file in the environment directory (gitignored):

```hcl
# envs/dev/terraform.tfvars
public_key  = "ssh-ed25519 AAAA..."
alarm_email = "you@example.com"
```

```bash
cd envs/dev
terraform init
terraform plan
terraform apply
```

### Accessing the application

| Environment | URL |
|---|---|
| dev | `https://dev.myinfracode.com` |
| prod | `https://myinfracode.com` |

Allow 1-2 minutes after apply for instances to boot and pass ALB health checks.

### Accessing instances

EC2 instances have no public IP. Use SSM Session Manager:

```bash
aws ssm start-session --target <instance-id>
```

Find the instance ID in the AWS console under EC2 → Instances, or:

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=webserver-dev" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text
```

### Retrieving database credentials

```bash
aws secretsmanager get-secret-value \
  --secret-id dev/rds/app \
  --query SecretString \
  --output text | jq .
```

---

## Key Terraform commands

| Command | Description |
|---|---|
| `terraform init` | Initialise working directory |
| `terraform plan` | Preview changes |
| `terraform apply` | Apply changes |
| `terraform destroy` | Destroy all managed resources |
| `terraform output` | Show current outputs |
| `terraform state list` | List all resources in state |
| `terraform force-unlock <id>` | Release a stuck state lock |

---

## Conventions

- **All changes go through PRs** — never apply directly to prod from a local machine
- **Never commit state files** — `.gitignore` excludes `*.tfstate`
- **Never commit `terraform.tfvars`** — gitignored; use GitHub secrets for CI/CD
- **Always review the plan** — read the plan comment before approving a prod deployment
- **Bootstrap is persistent** — the S3 bucket has `prevent_destroy = true`; never destroy it

---

## Cost awareness

| Resource | dev | prod |
|---|---|---|
| ALB | ~$0.008/hr | ~$0.008/hr |
| EC2 | t3.nano ~$0.005/hr | t3.small ~$0.021/hr |
| RDS | db.t3.micro ~$0.017/hr | db.t3.small ~$0.034/hr (Multi-AZ ×2) |
| NAT Gateway | ~$0.045/hr + data | ~$0.045/hr + data |
| WAF | ~$5/month + $0.60/1M requests | same |
| VPC Flow Logs | Minimal | Minimal |
| S3 + DynamoDB | < $1/month | < $1/month |

Tear down when not in use:

```bash
cd envs/dev
terraform destroy
```

> **Note:** prod RDS has `deletion_protection = true`. Disable it in `envs/prod/main.tf` before destroying.

---

## Troubleshooting

### ACM certificate stuck in `PENDING_VALIDATION`
Validation CNAME must resolve before ACM issues the cert. Wait 1-5 minutes and check Route 53 for the validation record.

### ALB returns 502 Bad Gateway
Instance may still be booting or failing health checks. Wait 2-3 minutes and check EC2 → Target Groups in the console.

### SNS alarm emails not arriving
Confirm the SNS subscription by clicking the link in the confirmation email AWS sends after first apply. Check spam.

### State lock not released
If a run is interrupted, the DynamoDB lock may stick:
```bash
terraform force-unlock <lock-id>
```
The lock ID appears in the error message.

### CI/CD plan job skipped
The plan jobs depend on `fmt-validate` passing. Check that job's logs for a formatting or validation error. Fix with `terraform fmt -recursive`.

---

## AWS resources managed

| Resource | Module |
|---|---|
| `aws_vpc`, `aws_subnet` (×4), `aws_internet_gateway` | vpc |
| `aws_nat_gateway`, `aws_eip` | vpc |
| `aws_route_table` (×2), `aws_route_table_association` (×4) | vpc |
| `aws_flow_log`, `aws_cloudwatch_log_group`, `aws_iam_role` | vpc |
| `aws_lb`, `aws_lb_target_group`, `aws_lb_listener` (×2) | webserver |
| `aws_security_group` (×2), `aws_launch_template`, `aws_autoscaling_group` | webserver |
| `aws_autoscaling_policy` (×2) | webserver |
| `aws_acm_certificate`, `aws_route53_record` (×2) | webserver |
| `aws_iam_role`, `aws_iam_instance_profile`, `aws_key_pair` | webserver |
| `aws_cloudwatch_log_group`, `aws_cloudwatch_metric_alarm` (×2), `aws_sns_topic` | webserver |
| `aws_db_instance`, `aws_db_subnet_group`, `aws_security_group` | rds |
| `aws_secretsmanager_secret`, `random_password` | rds |
| `aws_wafv2_web_acl`, `aws_wafv2_web_acl_association` | waf |
| `aws_wafv2_web_acl_logging_configuration`, `aws_cloudwatch_log_group` | waf |
| `aws_s3_bucket`, `aws_dynamodb_table` | bootstrap |
| `aws_iam_openid_connect_provider`, `aws_iam_role` | bootstrap |

---

## Getting help

- Terraform docs: [developer.hashicorp.com/terraform](https://developer.hashicorp.com/terraform)
- AWS provider docs: [registry.terraform.io/providers/hashicorp/aws](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- Project issues: [github.com/frnxcode/terraform-aws-infra/issues](https://github.com/frnxcode/terraform-aws-infra/issues)
