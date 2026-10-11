variable "name" {
  description = "Prefixo de nomes do ambiente"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev | test | prod)"
  type        = string
}

variable "assets_lifecycle_days" {
  description = "Expiração de versões antigas dos assets (dias)"
  type        = number
  default     = 180
}
