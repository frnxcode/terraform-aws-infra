# Onboarding Guide — terraform-aws-infra

This guide walks you through everything you need to understand, work with, and contribute to this project.

---

## What is this project?

`terraform-aws-infra` provisions production-grade AWS webserver infrastructure using Terraform. It deploys a Bitnami Tomcat application across `dev` and `prod` environments, each with its own VPC, Auto Scaling Group, Application Load Balancer, TLS certificate, DNS records, and CloudWatch observability. Changes are deployed exclusively through a GitHub Actions CI/CD pipeline.

---

## Prerequisites

| Tool | Purpose | Install |
|---|---|---|
| Terraform >= 1.0 | Infrastructure provisioning | [terraform.io](https://developer.hashicorp.com/terraform/install) |
| AWS CLI | AWS authentication | [aws.amazon.com/cli](https://aws.amazon.com/cli/) |
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

Install the hooks after cloning:

```bash
pre-commit install
```

This enforces `terraform fmt`, `terraform validate`, and `tflint` on every commit.

---

## Repository structure

```
terraform-aws-infra/
├── bootstrap/                  # One-time setup: state backend + GitHub OIDC role
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── providers.tf
├── envs/
│   ├── dev/                    # Development environment
│   │   ├── main.tf             # VPC + webserver module calls
│   │   ├── variables.tf        # public_key, ssh_allowed_cidr, alarm_email
│   │   ├── outputs.tf
│   │   └── providers.tf        # S3 backend + AWS provider
│   └── prod/                   # Production environment (same structure)
├── modules/
│   ├── vpc/                    # VPC, subnets, IGW, route tables
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── webserver/              # ASG, ALB, ACM, Route 53, IAM, CloudWatch
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
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

Each environment gets its own isolated VPC with:
- 2 public subnets across `us-west-2a` and `us-west-2b` — ALB and EC2 instances live here
- 2 private subnets — reserved for future use (e.g. RDS, private ASG)
- Internet Gateway + public route table

| Environment | VPC CIDR | Public subnets | Private subnets |
|---|---|---|---|
| dev | `10.0.0.0/16` | `10.0.1.0/24`, `10.0.2.0/24` | `10.0.101.0/24`, `10.0.102.0/24` |
| prod | `10.1.0.0/16` | `10.1.1.0/24`, `10.1.2.0/24` | `10.1.101.0/24`, `10.1.102.0/24` |

### Webserver module

The `modules/webserver` module is the core of each environment. It provisions:

- **Key pair** — registers your SSH public key with AWS
- **IAM role + instance profile** — grants SSM Session Manager access (no bastion host needed) and CloudWatch agent permissions
- **ALB security group** — accepts HTTP/HTTPS from the internet
- **Webserver security group** — accepts HTTP only from the ALB (not the open internet), SSH from a restricted CIDR
- **Application Load Balancer** — public, multi-AZ, HTTP redirects to HTTPS
- **ACM certificate** — DNS-validated TLS certificate for the environment domain
- **Route 53 records** — alias A record pointing the domain to the ALB, CNAME for cert validation
- **Launch Template** — EC2 configuration (AMI, instance type, IAM profile, security group)
- **Auto Scaling Group** — min 1 / max 3 / desired 1, spans both public subnets
- **CloudWatch log group** — `/{instance_name}/application`, 30-day retention
- **SNS topic + email subscription** — receives alarm notifications
- **CloudWatch alarms** — CPU > 80% and unhealthy host count > 0

### Remote state

Terraform state is stored in S3 with DynamoDB locking. Each environment has its own isolated state key — a destroy in dev has zero effect on prod.

| Environment | State key |
|---|---|
| dev | `envs/dev/terraform.tfstate` |
| prod | `envs/prod/terraform.tfstate` |

### CI/CD pipeline

All infrastructure changes go through GitHub Actions:

1. **Open a PR** → `terraform-plan.yml` runs fmt check, validate, and plan for both environments. The plan output is posted as a PR comment.
2. **Merge to main** → `terraform-apply.yml` automatically applies dev. Prod requires manual approval via the GitHub `prod` environment protection rule.

GitHub Actions authenticates to AWS using OIDC — no long-lived access keys are stored anywhere.

---

## First-time setup (bootstrap)

The bootstrap creates the S3 state bucket, DynamoDB lock table, and the GitHub Actions OIDC IAM role. Run this once per AWS account:

```bash
cd bootstrap
terraform init
terraform apply -var="github_repo=frnxcode/terraform-aws-infra"
```

Copy the `github_actions_role_arn` from the output — you'll need it in the next step.

### GitHub repository secrets

Go to **Settings → Secrets and variables → Actions** in the GitHub repo and add:

| Secret | Value |
|---|---|
| `AWS_ROLE_ARN` | Role ARN from bootstrap output |
| `TF_VAR_PUBLIC_KEY` | Your SSH public key (`cat ~/.ssh/id_ed25519_francis_mac.pub`) |
| `TF_VAR_SSH_ALLOWED_CIDR` | Your IP with `/32` (e.g. `1.2.3.4/32`) |
| `TF_VAR_ALARM_EMAIL` | Email address for CloudWatch alarm notifications |

### GitHub environments

Go to **Settings → Environments** and create:
- `dev` — no protection rules (applies automatically)
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

For running Terraform locally, create a `terraform.tfvars` file in the environment directory (gitignored):

```hcl
public_key       = "ssh-ed25519 AAAA..."
ssh_allowed_cidr = "YOUR_IP/32"
alarm_email      = "you@example.com"
```

```bash
cd envs/dev
terraform init
terraform plan
terraform apply
```

### Accessing the application

After apply, the application is available at:

| Environment | URL |
|---|---|
| dev | `https://dev.myinfracode.com` |
| prod | `https://myinfracode.com` |

Allow 1-2 minutes after apply for the ASG instance to boot and pass health checks before the ALB serves traffic.

To retrieve outputs at any time:

```bash
terraform output
```

### SSH access

```bash
ssh -i ~/.ssh/id_ed25519_francis_mac bitnami@<instance-public-ip>
```

Or use AWS Session Manager (no SSH key required):

```bash
aws ssm start-session --target <instance-id>
```

---

## Key Terraform commands

| Command | Description |
|---|---|
| `terraform init` | Initialise working directory, download providers and modules |
| `terraform plan` | Preview what changes will be made |
| `terraform apply` | Apply the planned changes |
| `terraform destroy` | Destroy all managed resources |
| `terraform output` | Show current outputs without re-applying |
| `terraform state list` | List all resources in state |
| `terraform state mv <src> <dst>` | Rename a resource in state without destroying it |
| `terraform force-unlock <lock-id>` | Release a stuck state lock |

---

## Conventions

- **All changes go through PRs** — never apply directly to prod from a local machine
- **Never commit state files** — `.gitignore` excludes `*.tfstate` and `*.tfstate.*`
- **Never commit `terraform.tfvars`** — gitignored; use GitHub secrets for CI/CD
- **Always review the plan** — before approving a prod deployment, read the plan comment on the PR
- **Bootstrap is persistent** — the S3 bucket has `prevent_destroy = true`; never destroy it
- **Destroy when not testing** — ALB and EC2 instances incur hourly costs; tear down idle environments

---

## Cost awareness

| Resource | Approx. cost |
|---|---|
| ALB | ~$0.008/hour (~$6/month) per environment |
| t3.nano (dev) | ~$0.005/hour |
| t3.small (prod) | ~$0.021/hour |
| S3 + DynamoDB | Minimal (< $1/month) |
| CloudWatch | Minimal for low traffic |

Tear down an environment when not in use:

```bash
cd envs/dev
terraform destroy
```

---

## Troubleshooting

### ACM certificate stuck in `PENDING_VALIDATION`
The certificate validation CNAME record must resolve before ACM issues the cert. This can take 1-5 minutes after apply. Check the Route 53 console to confirm the validation record exists.

### ALB returns 502 Bad Gateway
The ASG instance may still be booting or failing health checks. Wait 2-3 minutes and check the target group health in the AWS console (EC2 → Target Groups).

### SNS alarm emails not arriving
You must confirm the SNS subscription by clicking the link in the confirmation email AWS sends after the first apply. Check your spam folder.

### State lock not released
If a Terraform run is interrupted, the DynamoDB lock may not be released:
```bash
terraform force-unlock <lock-id>
```
The lock ID is shown in the error message.

### `InvalidGroup.Duplicate` on security group creation
Two resources with the same name exist in the VPC. Check the AWS console for orphaned security groups, delete them manually, then re-run `terraform apply`.

### CI/CD plan job skipped
The plan jobs depend on the `fmt-validate` job passing. If they are skipped, check the `fmt-validate` job logs for a formatting or validation error. Run `terraform fmt -recursive` locally and push a fix.

---

## AWS resources managed

| Resource | Module | Description |
|---|---|---|
| `aws_vpc` | vpc | Isolated network per environment |
| `aws_subnet` | vpc | 2 public + 2 private subnets |
| `aws_internet_gateway` | vpc | Public internet access |
| `aws_route_table` | vpc | Public subnet routing |
| `aws_key_pair` | webserver | SSH public key |
| `aws_iam_role` | webserver | EC2 instance role |
| `aws_iam_instance_profile` | webserver | Attaches role to instances |
| `aws_security_group` (x2) | webserver | ALB SG and webserver SG |
| `aws_lb` | webserver | Application Load Balancer |
| `aws_lb_target_group` | webserver | Health-checked target group |
| `aws_lb_listener` (x2) | webserver | HTTP redirect + HTTPS forward |
| `aws_acm_certificate` | webserver | TLS certificate |
| `aws_route53_record` (x2) | webserver | Alias A record + cert validation |
| `aws_launch_template` | webserver | EC2 instance configuration |
| `aws_autoscaling_group` | webserver | Auto Scaling Group |
| `aws_cloudwatch_log_group` | webserver | Application logs |
| `aws_sns_topic` | webserver | Alarm notification topic |
| `aws_cloudwatch_metric_alarm` (x2) | webserver | CPU + unhealthy hosts |
| `aws_s3_bucket` | bootstrap | Remote state storage |
| `aws_dynamodb_table` | bootstrap | State locking |
| `aws_iam_openid_connect_provider` | bootstrap | GitHub Actions OIDC |
| `aws_iam_role` | bootstrap | GitHub Actions CI/CD role |

---

## Getting help

- Terraform docs: [developer.hashicorp.com/terraform](https://developer.hashicorp.com/terraform)
- AWS provider docs: [registry.terraform.io/providers/hashicorp/aws](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- Project issues: [github.com/frnxcode/terraform-aws-infra/issues](https://github.com/frnxcode/terraform-aws-infra/issues)
