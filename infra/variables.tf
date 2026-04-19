variable "aws_region" {
  description = "AWS region for all resources (except CloudFront ACM cert which is always us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment label"
  type        = string
  default     = "dev"
}

variable "bucket_name" {
  description = "S3 bucket name for mail assets (must be globally unique)"
  type        = string
  default     = "assetport-mail-assets"
}

variable "ecr_repo_name" {
  description = "ECR repository name"
  type        = string
  default     = "assetport"
}

variable "instance_type" {
  description = "EC2 instance type. t2.micro is free-tier eligible."
  type        = string
  default     = "t2.micro"
}

variable "allowed_cidr" {
  description = "Your public IP in CIDR notation (e.g. 203.0.113.10/32). Used to restrict access to port 8501."
  type        = string
  # Replace with your actual IP: curl ifconfig.me
  default = "0.0.0.0/0"
}

variable "cloudfront_domain_alias" {
  description = "Optional custom domain for CloudFront (e.g. assets.yourdomain.com). Leave empty to use the default CloudFront domain."
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "SSH public key material for EC2 access (contents of your ~/.ssh/id_rsa.pub)"
  type        = string
  sensitive   = true
}
