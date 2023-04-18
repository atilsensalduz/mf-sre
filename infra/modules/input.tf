variable "name" {
  type        = string
  description = "The id of the machine image (AMI) to use for the server."
}

variable "cluster_version" {
  type        = string
  description = "The id of the machine image (AMI) to use for the server."
  default = "1.25"
}

variable "instance_types" {
  type    = list(string)
  description = "The id of the machine image (AMI) to use for the server."
  default = ["t3.medium"]
}

variable "capacity_type" {
  type    = string
  description = "The id of the machine image (AMI) to use for the server."
  default = "SPOT"
}

variable "region" {
  type    = string
  description = "The id of the machine image (AMI) to use for the server."
  default = "us-west-2"
}

variable "vpc_cidr" {
  type        = string
  description = "The id of the machine image (AMI) to use for the server."
}