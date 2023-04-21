variable "name" {
  type        = string
  description = "The name of the EKS Cluster."
}

variable "cluster_version" {
  type        = string
  description = "The version of the EKS Cluster."
  default = "1.25"
}

variable "instance_types" {
  type    = list(string)
  description = "The instance types of initial eks managed node group."
  default = ["t3.medium"]
}

variable "capacity_type" {
  type    = string
  description = "EKS managed node group ec2 instance capacity type"
  default = "SPOT"
}

variable "region" {
  type    = string
  description = "The region to deploy infra"
  default = "eu-west-1"
}

variable "vpc_cidr" {
  type        = string
  description = "The CIDR block of VPC"
}