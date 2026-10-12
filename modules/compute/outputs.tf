output "instance_id" {
  description = "ID da instância do stack POS"
  value       = module.ec2.id
}

output "instance_public_ip" {
  description = "IP público para o app de caixa apontar (http://IP:9000)"
  value       = module.ec2.public_ip
}

output "ecr_repository_url" {
  description = "Registry das imagens do backend POS neste ambiente"
  value       = aws_ecr_repository.app.repository_url
}

output "iam_instance_profile" {
  description = "Perfil da instância (SSM/ECR/S3)"
  value       = aws_iam_instance_profile.main.name
}
