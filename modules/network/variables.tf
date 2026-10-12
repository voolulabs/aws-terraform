variable "name" {
  description = "Prefixo de nomes do ambiente (ex.: voolulabs-pos-dev)"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev | test | prod)"
  type        = string
}

variable "cidr" {
  description = "CIDR da VPC — único por ambiente (evita overlap em peering futuro)"
  type        = string
}

variable "azs" {
  description = "Zonas de disponibilidade (sa-east-1: a/b)"
  type        = list(string)
  default     = ["sa-east-1a", "sa-east-1b"]
}

variable "enable_network_firewall" {
  description = "Decisão do dono: Network Firewall somente no prod (custo de centenas de USD/mês por AZ 24/7)"
  type        = bool
  default     = false
}

variable "public_ingress_cidrs" {
  description = "CIDRs com acesso às portas públicas do stack de homologação (9000 app / 8000 storefront)"
  type        = list(string)
  default     = ["0.0.0.0/0"] # homologação http público; restringir quando houver IP fixo do lojista
}
