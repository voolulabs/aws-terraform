variable "region" {
  description = "Região de todos os stacks (decisão 2026-10-11: sa-east-1)"
  type        = string
  default     = "sa-east-1"
}

variable "state_bucket_name" {
  description = "Nome globalmente único do bucket de estado Terraform — NÃO trocar depois que org/ e envs/ apontarem para ele"
  type        = string
  default     = "voolulabs-pos-tfstate-sa-east-1"
}
