# Stack one-time: bucket de estado que sustenta TODOS os demais stacks
# (org/, envs/*). Nada aqui depende de rede/AWS prévia além de credenciais.
module "state_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.5"

  bucket = var.state_bucket_name

  # Estado do Terraform: versioning + KMS + bloqueio total de acesso público.
  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = aws_kms_key.state.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  # Acesso ao estado restrito à conta de gestão (política aplicada no main.tf
  # via aws_s3_bucket_policy — módulo deixa montar a policy externamente).
  attach_public_policy    = false
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  lifecycle_rule = [
    {
      id      = "versionamento-antigo"
      enabled = true
      noncurrent_version_expiration = {
        days = 90
      }
    },
  ]

  tags = {
    Stack = "bootstrap"
  }
}

resource "aws_kms_key" "state" {
  description             = "Chave KMS do estado Terraform (voolulabs-pos)"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Stack = "bootstrap"
  }
}

resource "aws_kms_alias" "state" {
  name          = "alias/voolulabs-pos-tfstate"
  target_key_id = aws_kms_key.state.key_id
}

# Somente a conta de gestão toca no estado (dados + metadados de lockfile).
data "aws_iam_policy_document" "state" {
  statement {
    sid       = "SomenteContaGestao"
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = [module.state_bucket.s3_bucket_arn, "${module.state_bucket.s3_bucket_arn}/*"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid       = "ExigeTLS"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [module.state_bucket.s3_bucket_arn, "${module.state_bucket.s3_bucket_arn}/*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = module.state_bucket.s3_bucket_id
  policy = data.aws_iam_policy_document.state.json
}

data "aws_caller_identity" "current" {}
