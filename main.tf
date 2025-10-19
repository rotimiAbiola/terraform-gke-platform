data "google_client_config" "default" {}

# VPC Module
module "network" {
  source        = "./modules/network"
  project_id    = var.project_id
  region        = var.region
  network_name  = var.network_name
  subnet_config = var.subnet_config
}
