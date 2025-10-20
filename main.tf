data "google_client_config" "default" {}

# VPC Module
module "network" {
  source        = "./modules/network"
  project_id    = var.project_id
  region        = var.region
  network_name  = var.network_name
  subnet_config = var.subnet_config
}

# GKE Module
module "cluster" {
  source = "./modules/cluster"

  project_id   = var.project_id
  region       = var.region
  network_name = module.network.network_name
  subnet_name  = module.network.subnets["kubernetes"].name
  subnet_secondary_ranges = {
    pods     = module.network.subnets["kubernetes"].secondary_ip_range[0]
    services = module.network.subnets["kubernetes"].secondary_ip_range[1]
  }

  cluster_name               = var.cluster_name
  node_pools                 = var.node_pools
  master_ipv4_cidr           = var.master_ipv4_cidr
  master_authorized_networks = var.master_authorized_networks

  enable_private_endpoint = true
  enable_private_nodes    = true

  enable_etcd_encryption  = true
  kms_key_rotation_period = "7776000s"
}

# PostgreSQL Module
module "database" {
  source = "./modules/database"

  project_id      = var.project_id
  region          = var.region
  network_id      = module.network.network_id
  database_subnet = module.network.subnets["database"].name

  instance_name     = var.postgres_instance_name
  database_version  = var.postgres_version
  tier              = var.postgres_tier
  availability_type = var.postgres_availability_type
  disk_size         = var.postgres_disk_size

  databases = var.databases
  users     = var.users

  application_db_username = var.application_db_username
  db_charset              = "UTF8"
  db_collation            = "en_US.UTF8"

  authorized_networks = []
  enable_private_ip   = true
  private_network     = module.network.network_id

  enable_backup                 = true
  enable_point_in_time_recovery = true
  backup_location               = var.backup_region

  disk_autoresize = true
  ipv4_enabled    = false
}

# DNS Module - Private DNS for internal services
module "dns" {
  source = "./modules/dns"

  project_id          = var.project_id
  network_id          = module.network.network_id
  database_private_ip = module.database.private_ip_address

  dns_zone_name     = var.dns_zone_name
  dns_zone_domain   = var.dns_zone_domain
  database_dns_name = var.database_dns_name

  service_dns_records   = var.service_dns_records
  service_cname_records = var.service_cname_records

  depends_on = [module.database]
}