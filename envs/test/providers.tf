terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# O CI (e o humano admin) operam a conta membro assumindo a role criada junto
# com a conta no Organizations. O ID vem do output account_ids do stack org/
# (preencher o tfvars após o primeiro apply do org/).
provider "aws" {
  region = var.region
  # assume_role desligado quando o stack roda DENTRO da conta de execução
  # (temporário pós-cota: test roda na gestão até as contas membros abrirem).
  dynamic "assume_role" {
    for_each = var.assume_deployment_role ? [1] : []
    content {
      role_arn = "arn:aws:iam::${var.deployment_account_id}:role/OrganizationAccountAccessRole"
    }
  }

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    ManagedBy   = "Terraform"
    Stack       = "env-${var.environment}"
    GitRepo     = "https://github.com/voolulabs/aws-terraform"
    Environment = var.environment
  }
}
