variable "region" {
  description = "Região única de todos os ambientes (decisão do dono: sa-east-1)"
  type        = string
  default     = "sa-east-1"
}

variable "state_bucket_name" {
  description = "Bucket de estado criado pelo stack bootstrap (não trocar)"
  type        = string
  default     = "voolulabs-pos-tfstate-sa-east-1"
}

variable "trail_bucket_name" {
  description = "Bucket da trilha CloudTrail organizacional"
  type        = string
  default     = "voolulabs-pos-cloudtrail-sa-east-1"
}

variable "account_emails" {
  description = "Email ÚNICO por conta membro (usar alias do domínio do dono). PREENCHER antes do primeiro apply — a AWS exige email globalmente único por conta."
  type        = map(string)
  default = {
    dev  = "aws-dev@agenciavoolu.com"
    test = "aws-test@agenciavoolu.com"
    prod = "aws-prod@agenciavoolu.com"
  }
}

variable "github_repo" {
  description = "Repo autorizado a assumir as roles de CI (GitHub Actions OIDC)"
  type        = string
  default     = "voolulabs/aws-terraform"
}

variable "identity_center_enabled" {
  description = "true somente DEPOIS de habilitar o IAM Identity Center no console (região home sa-east-1)"
  type        = bool
  default     = false
}

variable "owner_user_name" {
  description = "Usuário Identity Center do dono"
  type        = string
  default     = "chico"
}

variable "owner_email" {
  description = "Email do dono no Identity Center"
  type        = string
  default     = "chico@agenciavoolu.com"
}

variable "owner_display_name" {
  description = "Nome exibido do dono"
  type        = string
  default     = "Chico Voolulabs"
}

variable "owner_given_name" {
  description = "Primeiro nome do dono"
  type        = string
  default     = "Chico"
}

variable "owner_family_name" {
  description = "Sobrenome do dono"
  type        = string
  default     = "Voolulabs"
}
