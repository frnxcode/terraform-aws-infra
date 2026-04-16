data "aws_route53_zone" "main" {
  name         = "myinfracode.com"
  private_zone = false
}

module "vpc" {
  source = "../../modules/vpc"

  env_name             = "prod"
  vpc_cidr             = "10.1.0.0/16"
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.101.0/24", "10.1.102.0/24"]
}

module "waf" {
  source = "../../modules/waf"

  env_name = "prod"
  alb_arn  = module.webserver.alb_arn
}

module "rds" {
  source = "../../modules/rds"

  env_name            = "prod"
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnet_ids
  webserver_sg_id     = module.webserver.webserver_sg_id
  instance_class      = "db.t3.small"
  multi_az            = true
  skip_final_snapshot = false
  deletion_protection = true
}

resource "aws_iam_role_policy" "webserver_secrets" {
  name = "webserver-prod-secrets"
  role = module.webserver.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = module.rds.secret_arn
    }]
  })
}

module "webserver" {
  source         = "../../modules/webserver"
  instance_type  = "t3.small"
  instance_name  = "webserver-prod"
  vpc_id         = module.vpc.vpc_id
  alb_subnet_ids = module.vpc.public_subnet_ids
  subnet_ids     = module.vpc.private_subnet_ids
  public_key     = var.public_key
  alarm_email    = var.alarm_email
  zone_id        = data.aws_route53_zone.main.zone_id
  domain_name    = "myinfracode.com"
}
