# Aplicado a partir da conta de gestão (management). O primeiro apply usa as
# credenciais temporárias do `aws login` root; as re-aplicações seguintes usam
# o usuário admin do Identity Center (nunca mais root).
provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    ManagedBy = "Terraform"
    Stack     = "org"
    GitRepo   = "https://github.com/voolulabs/aws-terraform"
  }
}
