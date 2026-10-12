terraform {
  backend "s3" {
    bucket       = "voolulabs-pos-tfstate-sa-east-1"
    key          = "envs/dev/terraform.tfstate"
    region       = "sa-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
