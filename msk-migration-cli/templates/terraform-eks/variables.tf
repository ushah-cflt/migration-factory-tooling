variable "region" {
  type        = string
  description = "AWS region to deploy EKS"
  default     = "us-west-2"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for worker nodes"
  default     = "m5.xlarge"
}

# Already existing from before:
variable "desired_node_count" {
  type        = number
  description = "Number of EC2 worker nodes"
  default     = 3
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC to deploy the cluster into"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs within the VPC"
}

variable "aws_account_id" {
  type        = string
  description = "aws_account_id"
}

variable "cluster_name" {
  type        = string
  description = "Name of the eks cluster"
  default     = "msk-cc-migration-eks-cluster"
}