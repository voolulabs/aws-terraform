locals {
  name = "voolulabs-pos-${var.environment}"
}

module "network" {
  source = "../../modules/network"

  name                    = local.name
  environment             = var.environment
  cidr                    = var.cidr
  enable_network_firewall = var.enable_network_firewall
}

module "storage" {
  source = "../../modules/storage"

  name        = local.name
  environment = var.environment
}

module "compute" {
  source = "../../modules/compute"

  name               = local.name
  environment        = var.environment
  vpc_id             = module.network.vpc_id
  subnet_id          = module.network.public_subnet_ids[0]
  public_stack_sg_id = module.network.public_stack_sg_id
  instance_type      = var.instance_type
  stop_schedule_cron = var.stop_schedule_cron
  assets_bucket_arn  = module.storage.assets_bucket_arn
}
