module "vpc" {
  source = "../../modules/vpc"

  env_name             = "prod"
  vpc_cidr             = "10.1.0.0/16"
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.101.0/24", "10.1.102.0/24"]
}

module "webserver" {
  source           = "../../modules/webserver"
  instance_type    = "t3.small"
  instance_name    = "webserver-prod"
  vpc_id           = module.vpc.vpc_id
  subnet_id        = module.vpc.public_subnet_ids[0]
  public_key       = var.public_key
  ssh_allowed_cidr = var.ssh_allowed_cidr
}
