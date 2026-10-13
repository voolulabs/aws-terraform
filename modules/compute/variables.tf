variable "name" {
  description = "Prefixo de nomes do ambiente"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev | test | prod)"
  type        = string
}

variable "subnet_id" {
  description = "Subnet pública da instância do stack POS"
  type        = string
}

variable "public_stack_sg_id" {
  description = "SG com as portas públicas do stack"
  type        = string
}

variable "instance_type" {
  description = "Tamanho da instância (dev/test pequena, prod maior)"
  type        = string
}

variable "associate_public_ip" {
  description = "IP público para acesso http de homologação"
  type        = bool
  default     = true
}

variable "stop_schedule_cron" {
  description = "Cron de desligamento noturno (decisão do dono: schedule + power-on manual quando quiser). Vazio = sempre ligado."
  type        = string
  default     = "cron(0 6 * * ? *)" # 03:00 BRT todos os dias
}

variable "assets_bucket_arn" {
  description = "ARN do bucket de assets (acesso de leitura do perfil da instância)"
  type        = string
  default     = null
}

# Gate booleano conhecido no plan: count por output de módulo (ARN) é unknown
# até aplicar e invalida o count; o bool decola a criação, o ARN é resolvido
# no apply.
variable "enable_assets_access" {
  description = "Perfil da instância lê o bucket de assets"
  type        = bool
  default     = false
}
