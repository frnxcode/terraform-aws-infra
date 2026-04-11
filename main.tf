module "webserver" {
  source        = "./modules/webserver"
  instance_type = var.instance_type
  instance_name = var.instance_name
}
