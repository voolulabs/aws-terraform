# Bootstrap roda UMA vez, a partir da conta de gestão (management), com
# credenciais temporárias do `aws login` root — o estado dele é LOCAL por
# definição (ele cria o bucket que sustenta todos os demais estados).
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Stack     = "bootstrap"
      GitRepo   = "https://github.com/voolulabs/aws-terraform"
    }
  }
}
