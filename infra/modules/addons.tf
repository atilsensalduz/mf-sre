# Generate RSA SSH key for the ArgoCD repository.
resource "tls_private_key" "argocd_repository_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create a deploy key in the workload repository to allow ArgoCD to deploy workloads.
resource "github_repository_deploy_key" "workload_repository_deploy_key" {
  title      = "ArgoCD Deploy Key"
  repository = var.argocd_repository_name
  key        = tls_private_key.argocd_repository_ssh_key.public_key_openssh
  read_only  = "false"
}

# Store the ArgoCD repository SSH private key in AWS Secrets Manager.
resource "aws_secretsmanager_secret" "argocd_application_repository_ssh_key" {
  name                    = "argocd_repository_ssh_key"
  recovery_window_in_days = 0 # Set to zero for this example to force delete during Terraform destroy
}

# Store the ArgoCD repository SSH private key as a secret value in AWS Secrets Manager.
resource "aws_secretsmanager_secret_version" "argocd_application_repository_ssh_key" {
  secret_id     = aws_secretsmanager_secret.argocd_application_repository_ssh_key.id
  secret_string = tls_private_key.argocd_repository_ssh_key.private_key_openssh
}

################################################################################
# Kubernetes Addons
################################################################################

# Import the `kubernetes-addons` module from the official EKS blueprint repository.
module "eks_blueprints_kubernetes_addons" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints/modules/kubernetes-addons"

  # The ID of the EKS cluster
  eks_cluster_id = module.eks.cluster_name

  # The endpoint of the EKS cluster's Kubernetes API server
  eks_cluster_endpoint = module.eks.cluster_endpoint

  # The OIDC identity provider used by the EKS cluster
  eks_oidc_provider = module.eks.oidc_provider

  # The version of the EKS cluster's Kubernetes API server
  eks_cluster_version = module.eks.cluster_version

  # Enable the following EKS add-ons.
  enable_amazon_eks_vpc_cni            = true
  enable_amazon_eks_coredns            = true
  enable_amazon_eks_kube_proxy         = true
  enable_amazon_eks_aws_ebs_csi_driver = true

  # Enable ArgoCD add-on.
  enable_argocd = true

  # Configure ArgoCD settings with the following Helm chart config options.
  argocd_helm_config = {
    set_sensitive = [
      {
        name  = "configs.secret.argocdServerAdminPassword"
        value = bcrypt_hash.argo.id
      }
    ]
  }

  # Enable the ArgoCD add-ons management.
  argocd_manage_add_ons = true

  # Define the application repositories that ArgoCD will manage.
  argocd_applications = {
    # Define the `addons` application repository that will deploy add-ons in the cluster.
    addons = {
      path               = "chart"
      repo_url           = "https://github.com/aws-samples/eks-blueprints-add-ons.git"
      add_on_application = true
    }
    # Define the `workloads` application repository that will deploy workloads in the cluster.
    workloads = {
      path                = "cd/apps"
      repo_url            = "git@github.com:atilsensalduz/mf-sre.git"
      add_on_application  = false
      ssh_key_secret_name = "argocd_repository_ssh_key"
    }
    # Define the `infra-workloads` application repository that will deploy infrastructure workloads in the cluster.
    infra-workloads = {
      path                = "cd/infra"
      repo_url            = "git@github.com:atilsensalduz/mf-sre.git"
      add_on_application  = false
      ssh_key_secret_name = "argocd_repository_ssh_key"
    }

  }


  # Add-ons
  enable_karpenter      = true
  enable_keda           = false
  enable_metrics_server = true
  enable_argo_rollouts  = true

  karpenter_node_iam_instance_profile        = module.karpenter.instance_profile_name
  karpenter_enable_spot_termination_handling = true
}

#---------------------------------------------------------------
# ArgoCD Admin Password credentials with Secrets Manager
# Login to AWS Secrets manager with the same role as Terraform to extract the ArgoCD admin password with the secret name as "argocd"
#---------------------------------------------------------------
# Create a secure password for the ArgoCD admin account and encrypt it with bcrypt
# to meet ArgoCD's password requirements
resource "random_password" "argocd" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "bcrypt_hash" "argo" {
  cleartext = random_password.argocd.result
}

# Create an AWS Secrets Manager secret to store the encrypted ArgoCD admin password
# with the secret name "argocd"
resource "aws_secretsmanager_secret" "argocd" {
  name                    = "argocd"
  recovery_window_in_days = 0 # Set to zero for this example to force delete during Terraform destroy
}

# Add the password to the AWS Secrets Manager secret
resource "aws_secretsmanager_secret_version" "argocd" {
  secret_id     = aws_secretsmanager_secret.argocd.id
  secret_string = random_password.argocd.result
}

# Use the Terraform module "terraform-aws-modules/eks/aws//modules/karpenter"
# to deploy Karpenter, a Kubernetes Autoscaler based on AWS Fargate
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 19.12"

  cluster_name           = module.eks.cluster_name
  irsa_oidc_provider_arn = module.eks.oidc_provider_arn
  create_irsa            = false # IRSA will be created by the kubernetes-addons module
  iam_role_arn           = module.eks.eks_managed_node_groups["initial"].iam_role_arn
}

# Create a Karpenter Provisioner manifest to specify the requirements and limits for the Autoscaler
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

  # Ensure the Karpenter Provisioner manifest is deployed after the Kubernetes addons module has completed its deployment
  depends_on = [
    module.eks_blueprints_kubernetes_addons
  ]
}

# Create a Karpenter NodeTemplate manifest to specify the configuration for the worker nodes
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

  # Ensure the Karpenter NodeTemplate manifest is deployed after the Kubernetes addons module has completed its deployment
  depends_on = [
    module.eks_blueprints_kubernetes_addons
  ]
}
