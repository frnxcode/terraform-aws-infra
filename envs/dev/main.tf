data "aws_route53_zone" "main" {
  name         = "myinfracode.com"
  private_zone = false
}

module "vpc" {
  source = "../../modules/vpc"

  env_name             = "dev"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24"]
}

module "waf" {
  source = "../../modules/waf"

  env_name = "dev"
  alb_arn  = module.webserver.alb_arn
}

module "rds" {
  source = "../../modules/rds"

  env_name        = "dev"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  webserver_sg_id = module.webserver.webserver_sg_id
  instance_class  = "db.t3.micro"
}

resource "aws_iam_role_policy" "webserver_secrets" {
  name = "webserver-dev-secrets"
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
  instance_type  = "t3.nano"
  instance_name  = "webserver-dev"
  vpc_id         = module.vpc.vpc_id
  alb_subnet_ids = module.vpc.public_subnet_ids
  subnet_ids     = module.vpc.private_subnet_ids
  public_key     = var.public_key
  alarm_email    = var.alarm_email
  zone_id        = data.aws_route53_zone.main.zone_id
  domain_name    = "dev.myinfracode.com"
}
