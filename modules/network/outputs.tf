output "vpc_id" {
  description = "ID da VPC do ambiente"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Subnets públicas (instância do stack POS)"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "Subnets privadas (futuro: banco, serviços internos)"
  value       = module.vpc.private_subnets
}

output "public_stack_sg_id" {
  description = "SG com as portas públicas do stack"
  value       = aws_security_group.public_stack.id
}
