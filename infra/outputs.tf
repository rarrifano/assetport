output "ec2_public_ip" {
  description = "Public IP of the Assetport EC2 instance"
  value       = aws_instance.assetport.public_ip
}

output "app_url" {
  description = "Direct URL to the Assetport upload app"
  value       = "http://${aws_instance.assetport.public_ip}:8501"
}

output "s3_bucket_name" {
  description = "S3 bucket storing mail assets"
  value       = aws_s3_bucket.assets.bucket
}

output "cloudfront_domain" {
  description = "CloudFront domain for public asset URLs"
  value       = "https://${aws_cloudfront_distribution.assets.domain_name}"
}

output "ecr_repository_url" {
  description = "ECR repository URL for Docker image pushes"
  value       = aws_ecr_repository.assetport.repository_url
}
