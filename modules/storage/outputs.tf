output "assets_bucket_arn" {
  description = "ARN do bucket de assets"
  value       = module.assets.s3_bucket_arn
}

output "assets_bucket_name" {
  description = "Nome do bucket de assets (S3_FILE_URL da aplicação)"
  value       = module.assets.s3_bucket_id
}

output "logs_bucket_name" {
  description = "Nome do bucket de logs"
  value       = module.logs.s3_bucket_id
}
