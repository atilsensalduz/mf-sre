locals {
  argocd_repositories = {
    "repo" = {
      name          = var.name
      url           = var.argocd_repository_url
      type          = "git"
      sshPrivateKey = tls_private_key.argocd_repository_ssh_key
    }
  }
}

resource "tls_private_key" "argocd_repository_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "github_repository_deploy_key" "example_repository_deploy_key" {
  title      = "ArgoCD Deploy Key"
  repository = var.argocd_repository_name
  key        = tls_private_key.argocd_repository_ssh_key.public_key_openssh
  read_only  = "false"
}

################################################################################
# Kubernetes Addons
################################################################################
module "eks_blueprints_kubernetes_addons" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints/modules/kubernetes-addons"

  eks_cluster_id       = module.eks.cluster_name
  eks_cluster_endpoint = module.eks.cluster_endpoint
  eks_oidc_provider    = module.eks.oidc_provider
  eks_cluster_version  = module.eks.cluster_version

  # EKS Addons
  enable_amazon_eks_vpc_cni            = true
  enable_amazon_eks_coredns            = true
  enable_amazon_eks_kube_proxy         = true
  enable_amazon_eks_aws_ebs_csi_driver = true

  enable_argocd = true
  # This example shows how to set default ArgoCD Admin Password using SecretsManager with Helm Chart set_sensitive values.
  argocd_helm_config = {
    set = [
      {
        name  = "configs.repositories"
        value = local.argocd_repositories
      }
    ]
    set_sensitive = [
      {
        name  = "configs.secret.argocdServerAdminPassword"
        value = bcrypt_hash.argo.id
      }
    ]
  }

  argocd_manage_add_ons = true # Indicates that ArgoCD is responsible for managing/deploying add-ons
  argocd_applications = {
    addons = {
      path               = "chart"
      repo_url           = "https://github.com/aws-samples/eks-blueprints-add-ons.git"
      add_on_application = true
    }
    workloads = {
      path               = "cd/apps"
      repo_url           = "git@github.com:atilsensalduz/mf-sre.git"
      add_on_application = false
    }
    infra-workloads = {
      path               = "cd/infra"
      repo_url           = "git@github.com:atilsensalduz/mf-sre.git"
      add_on_application = false
    }

  }


  # Add-ons
  enable_karpenter      = true
  enable_keda           = false
  enable_metrics_server = true
  enable_argo_rollouts  = true
}

#---------------------------------------------------------------
# ArgoCD Admin Password credentials with Secrets Manager
# Login to AWS Secrets manager with the same role as Terraform to extract the ArgoCD admin password with the secret name as "argocd"
#---------------------------------------------------------------


resource "random_password" "argocd" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Argo requires the password to be bcrypt, we use custom provider of bcrypt,
# as the default bcrypt function generates diff for each terraform plan
resource "bcrypt_hash" "argo" {
  cleartext = random_password.argocd.result
}

resource "aws_secretsmanager_secret" "argocd" {
  name                    = "argocd"
  recovery_window_in_days = 0 # Set to zero for this example to force delete during Terraform destroy
}

resource "aws_secretsmanager_secret_version" "argocd" {
  secret_id     = aws_secretsmanager_secret.argocd.id
  secret_string = random_password.argocd.result
}

data "aws_ssm_parameter" "argocd_repository_ssh_key" {
  name            = "argocd_repository_ssh_key"
}

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 19.12"

  cluster_name           = module.eks.cluster_name
  irsa_oidc_provider_arn = module.eks.oidc_provider_arn
  create_irsa            = false # IRSA will be created by the kubernetes-addons module

}

resource "kubectl_manifest" "karpenter_provisioner" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: default
    spec:
      requirements:
        - key: "karpenter.k8s.aws/instance-category"
          operator: In
          values: ["t", "m"]
        - key: "karpenter.k8s.aws/instance-cpu"
          operator: In
          values: ["2", "4", "8"]
        - key: "karpenter.k8s.aws/instance-hypervisor"
          operator: In
          values: ["nitro"]
        - key: "karpenter.sh/capacity-type" 
          operator: In
          values: ["spot", "on-demand"]
      limits:
        resources:
          cpu: 1000
      consolidation:
        enabled: true
      providerRef:
        name: default
      ttlSecondsUntilExpired: 604800 # 7 Days = 7 * 24 * 60 * 60 Seconds
  YAML

  depends_on = [
    module.eks_blueprints_kubernetes_addons
  ]
}

resource "kubectl_manifest" "karpenter_node_template" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: default
    spec:
      subnetSelector:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelector:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      instanceProfile: ${module.karpenter.instance_profile_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
  YAML

  depends_on = [
    module.eks_blueprints_kubernetes_addons
  ]
}
