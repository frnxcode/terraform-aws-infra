module "webserver" {
  source        = "../../modules/webserver"
  instance_type = "t3.nano"
  instance_name = "webserver-dev"
}
