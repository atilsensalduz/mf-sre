


locals {
  region = "eu-west-1"
}
provider "aws" {
  region = local.region
}

data "aws_ssm_parameter" "argocd_repository_ssh_key" {
  name            = "argocd_repository_ssh_key"
  with_decryption = false
}

module "infrastructure" {
  source = "./modules"

  name = "demo"

  vpc_cidr = "10.0.0.0/16"

  cluster_version = "1.25"
  instance_types  = ["t3.medium"]
  capacity_type   = "SPOT"
  region          = local.region

  argocd_repository_url     = "git@github.com:atilsensalduz/mf-sre.git"
  argocd_repository_ssh_key = data.aws_ssm_parameter.argocd_repository_ssh_key
}
