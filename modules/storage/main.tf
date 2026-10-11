# Assets da aplicação (uploads do Medusa com S3 habilitado, artefatos de
# build). Criptografia AES256 (KMS por env é overkill na fase atual — revisitar
# no hardening P3+).
module "assets" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.5"

  bucket                   = "${var.name}-assets"
  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  lifecycle_rule = [
    {
      id      = "versoes-antigas"
      enabled = true
      noncurrent_version_expiration = {
        days = var.assets_lifecycle_days
      }
    },
  ]

  tags = { Environment = var.environment }
}

# Logs da aplicação/instância (CloudWatch continua sendo o caminho primário;
# este bucket absorve exports e artefatos de debugging).
module "logs" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.5"

  bucket                   = "${var.name}-logs"
  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  lifecycle_rule = [
    {
      id         = "expirar-logs"
      enabled    = true
      expiration = { days = 365 }
    },
  ]

  tags = { Environment = var.environment }
}
