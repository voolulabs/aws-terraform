output "state_bucket_name" {
  description = "Nome do bucket de estado — usado no backend de todos os stacks"
  value       = module.state_bucket.s3_bucket_id
}

output "state_kms_key_arn" {
  description = "ARN da chave KMS que criptografa o estado"
  value       = aws_kms_key.state.arn
}
