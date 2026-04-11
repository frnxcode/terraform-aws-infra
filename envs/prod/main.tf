module "webserver" {
  source        = "../../modules/webserver"
  instance_type = "t3.small"
  instance_name = "webserver-prod"
}
