variable "region" {
  description = "Região única (decisão do dono: sa-east-1)"
  type        = string
  default     = "sa-east-1"
}

variable "environment" {
  description = "Ambiente deste root module"
  type        = string
}

variable "deployment_account_id" {
  description = "ID da conta membro deste ambiente (saída account_ids do org/)"
  type        = string
}

variable "cidr" {
  description = "CIDR da VPC do ambiente (único por ambiente)"
  type        = string
}

variable "instance_type" {
  description = "Instância do stack POS"
  type        = string
}

variable "enable_network_firewall" {
  description = "Network Firewall (decisão: somente prod)"
  type        = bool
  default     = false
}

variable "stop_schedule_cron" {
  description = "Cron de stop noturno; vazio = 24/7"
  type        = string
  default     = ""
}
