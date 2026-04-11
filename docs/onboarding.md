# Onboarding Guide — terraform-aws-infra

This guide walks you through everything you need to understand, work with, and contribute to this project.

---

## What is this project?

`terraform-aws-infra` is an AWS infrastructure project managed with Terraform. It provisions EC2 webserver instances with security groups across isolated `dev` and `prod` environments, using a shared reusable module and a remote state backend.

---

## Prerequisites

Before you begin, ensure you have the following installed and configured:

| Tool | Purpose | Install |
|---|---|---|
| Terraform >= 1.0 | Infrastructure provisioning | [terraform.io](https://developer.hashicorp.com/terraform/install) |
| AWS CLI | AWS authentication | [aws.amazon.com/cli](https://aws.amazon.com/cli/) |
| Git | Version control | [git-scm.com](https://git-scm.com) |
| GitHub CLI (`gh`) | Repo management | `brew install gh` |

### AWS credentials

Configure your AWS credentials before running any Terraform commands:

```bash
aws configure
```

You will be prompted for:
- AWS Access Key ID
- AWS Secret Access Key
- Default region: `us-west-2`
- Default output format: `json`

---

## Repository structure

```
terraform-aws-infra/
├── bootstrap/              # One-time setup: S3 bucket + DynamoDB lock table
│   ├── main.tf
│   ├── outputs.tf
│   └── providers.tf
├── envs/
│   ├── dev/                # Development environment
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── providers.tf
│   └── prod/               # Production environment
│       ├── main.tf
│       ├── outputs.tf
│       └── providers.tf
├── modules/
│   └── webserver/          # Reusable EC2 + security group module
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── docs/
│   └── onboarding.md       # This file
├── providers.tf            # AWS provider + S3 backend config
└── .gitignore
```

---

## Core concepts

### Modules

The `modules/webserver` module is the building block of this project. It provisions:
- An EC2 instance using the latest Bitnami Tomcat AMI
- A security group allowing HTTP (port 80) and HTTPS (port 443) inbound traffic

Both `dev` and `prod` environments call this module with different inputs — same code, different configuration.

### Remote state

Terraform state is stored remotely in S3 rather than on local disk. This means:
- State is shared — anyone with AWS access can run Terraform against the same infrastructure
- State is versioned — you can roll back to a previous state if something goes wrong
- State is locked — DynamoDB prevents two people from running `apply` simultaneously

Each environment has its own isolated state file:

| Environment | State key |
|---|---|
| root | `global/s3/terraform.tfstate` |
| dev | `envs/dev/terraform.tfstate` |
| prod | `envs/prod/terraform.tfstate` |

### Environments

`dev` and `prod` are completely isolated — separate state, separate AWS resources. A `destroy` in `dev` has no effect on `prod`.

| Environment | Instance type | Use |
|---|---|---|
| dev | `t3.nano` | Testing and development |
| prod | `t3.small` | Production workloads |

---

## First-time setup (bootstrap)

The bootstrap config creates the S3 bucket and DynamoDB table used for remote state. This only needs to be run once per AWS account.

```bash
cd bootstrap
terraform init
terraform apply
```

This provisions:
- S3 bucket: `terraform-aws-infra-state-<account-id>` (versioned, encrypted, private)
- DynamoDB table: `terraform-aws-infra-locks`

> The S3 bucket has `prevent_destroy = true` — Terraform will refuse to delete it to protect state history.

---

## Day-to-day workflow

### Working in an environment

Always `cd` into the environment directory before running Terraform commands.

```bash
# Development
cd envs/dev
terraform init      # first time only, or after provider/module changes
terraform plan      # preview changes
terraform apply     # apply changes
terraform destroy   # tear down all resources
```

```bash
# Production
cd envs/prod
terraform init
terraform plan
terraform apply
```

### Accessing the application after apply

After a successful `terraform apply`, Terraform outputs the public IP and DNS of the instance:

```
Outputs:

public_ip  = "44.251.243.8"
public_dns = "ec2-44-251-243-8.us-west-2.compute.amazonaws.com"
```

Open a browser and navigate to:

```
http://<public_ip>
```

You should see the Bitnami Tomcat welcome page. Allow 1-2 minutes after apply for the instance to fully boot before accessing it.

To retrieve the outputs at any time without re-applying:

```bash
terraform output
```

### Standard workflow for making changes

1. Edit the relevant Terraform files (module or environment config)
2. Run `terraform plan` to review the impact
3. Run `terraform apply` to apply
4. Commit and push to GitHub

```bash
git add .
git commit -m "describe your change"
git push
```

---

## Key Terraform commands

| Command | Description |
|---|---|
| `terraform init` | Initialise working directory, download providers and modules |
| `terraform plan` | Preview what changes will be made |
| `terraform apply` | Apply the planned changes |
| `terraform destroy` | Destroy all managed resources |
| `terraform state mv <src> <dst>` | Rename a resource in state without destroying it |
| `terraform init -migrate-state` | Migrate state to a new backend |

---

## Important conventions

- **Always run `terraform plan` before `apply`** — never apply blindly
- **Never commit state files** — `.gitignore` excludes `*.tfstate` and `*.tfstate.*`
- **Use `terraform state mv` when renaming** — avoids unnecessary destroy/recreate
- **Bootstrap infrastructure is persistent** — do not destroy the S3 bucket or DynamoDB table
- **`create_before_destroy` on security groups** — prevents dependency violations when renaming

---

## Troubleshooting

### `DependencyViolation` when destroying a security group
AWS won't delete a security group that's still attached to an instance. This project uses `create_before_destroy = true` on security groups to handle this automatically. If you hit this manually, check that the instance has been terminated first.

### `Saved plan is stale`
The saved plan file (`tfplan`) is invalidated if state changes after the plan was created (e.g. a `destroy` run). Re-run `terraform plan` to generate a fresh plan.

### `InvalidGroup.Duplicate` on security group creation
Two resources with the same name exist in the same VPC. This can happen during a failed rename. Check the AWS console for orphaned security groups and delete them manually, then re-run `terraform apply`.

### State lock not released
If a Terraform run is interrupted, the DynamoDB lock may not be released. Run:
```bash
terraform force-unlock <lock-id>
```
The lock ID is shown in the error message.

---

## AWS resources managed

| Resource | Description |
|---|---|
| `aws_instance` | EC2 webserver instance |
| `aws_security_group` | Inbound HTTP/HTTPS rules |
| `aws_s3_bucket` | Remote state storage |
| `aws_dynamodb_table` | State locking |

---

## Getting help

- Terraform docs: [developer.hashicorp.com/terraform](https://developer.hashicorp.com/terraform)
- AWS provider docs: [registry.terraform.io/providers/hashicorp/aws](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- Project issues: [github.com/frnxcode/terraform-aws-infra/issues](https://github.com/frnxcode/terraform-aws-infra/issues)
