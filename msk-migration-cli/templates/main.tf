provider "aws" {
  region = var.region
}

resource "random_id" "role_suffix" {
  byte_length = 3
}

locals {
  eks_cluster_role = "eksClusterRole-${random_id.role_suffix.hex}"
}

locals {
  eks_node_group_role = "eksNodeGroupRole-${random_id.role_suffix.hex}"
}

locals {
  ebs_csi_driver_role = "EBSCSIDriverRole-${random_id.role_suffix.hex}"
}



# EKS Cluster IAM Role
resource "aws_iam_role" "eks_cluster_role" {
  name = local.eks_cluster_role

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# EKS Cluster
resource "aws_eks_cluster" "eks" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
# Add security group if required
  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    subnet_ids = var.subnet_ids
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy
  ]
}

# Node Group IAM Role
resource "aws_iam_role" "eks_node_group_role" {
  name = local.eks_node_group_role

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group_role.name
}

# Node Group
resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "msk-cc-node-group"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = var.desired_node_count
    max_size     = var.desired_node_count
    min_size     = var.desired_node_count
  }

  instance_types = [var.instance_type]

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly
  ]
}

resource "null_resource" "eksctl_create_iam_oidc_provider" {
  provisioner "local-exec" {
    command = <<EOT
      eksctl utils associate-iam-oidc-provider \
        --region=${var.region} \
        --cluster=${aws_eks_cluster.eks.name} \
        --approve
    EOT
  }

}

# Create IAM Service Account
resource "null_resource" "eksctl_create_iam_service_account" {
  provisioner "local-exec" {
    command = <<EOT
      eksctl create iamserviceaccount \
        --name ebs-csi-controller-sa \
        --namespace kube-system \
        --cluster ${aws_eks_cluster.eks.name} \
        --role-name ${local.ebs_csi_driver_role} \
        --role-only \
        --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
        --region ${var.region} \
        --approve
    EOT
  }
  depends_on = [
    null_resource.eksctl_create_iam_oidc_provider
  ]
}

#Add the Amazon EBS CSI add-on using eksctl
resource "null_resource" "eksctl_create_addon" {
  provisioner "local-exec" {
    command = <<EOT
      eksctl create addon \
        --name aws-ebs-csi-driver \
        --cluster ${aws_eks_cluster.eks.name} \
        --region ${var.region} \
        --service-account-role-arn arn:aws:iam::${var.aws_account_id}:role/${local.ebs_csi_driver_role} \
        --force
    EOT
  }
  depends_on = [
    null_resource.eksctl_create_iam_oidc_provider,null_resource.eksctl_create_iam_service_account
  ]
}





output "eks_cluster_name" {
  value       = aws_eks_cluster.eks.name
  description = "Name of the EKS cluster"
}

output "eks_cluster_endpoint" {
  value       = aws_eks_cluster.eks.endpoint
  description = "Endpoint for the EKS control plane"
}

output "kubeconfig_command" {
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.eks.name} --region ${var.region}"
  description = "Run this command to configure kubectl"
}

output "desired_node_count" {
  value       = "${var.desired_node_count}"
  description = "Run this command to configure kubectl"
}