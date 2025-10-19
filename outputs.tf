output "vpc_network" {
  description = "The VPC network"
  value       = module.network.network_name
}
