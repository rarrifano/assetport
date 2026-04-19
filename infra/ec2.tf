# ---------------------------------------------------------------------------
# EC2 — t2.micro (free-tier eligible) running the Dockerised Streamlit app
# ---------------------------------------------------------------------------

# Latest Amazon Linux 2023 AMI — maintained by AWS, free to use
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_key_pair" "assetport" {
  key_name   = "assetport-key"
  public_key = var.ssh_public_key
}

resource "aws_instance" "assetport" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.assetport.key_name
  iam_instance_profile   = aws_iam_instance_profile.assetport.name
  vpc_security_group_ids = [aws_security_group.assetport.id]

  # Ensure public IP is assigned (needed without ALB for free-tier)
  associate_public_ip_address = true

  # Bootstrap script — runs once on first boot
  user_data = templatefile("${path.module}/user_data.sh", {
    aws_region        = var.aws_region
    ecr_repo_url      = aws_ecr_repository.assetport.repository_url
    bucket_name       = var.bucket_name
    cloudfront_domain = "https://${aws_cloudfront_distribution.assets.domain_name}"
  })

  # Ensure ECR and S3 exist before instance boots
  depends_on = [
    aws_ecr_repository.assetport,
    aws_s3_bucket.assets,
    aws_iam_instance_profile.assetport,
  ]

  root_block_device {
    volume_size = 8 # GB — free tier covers 30GB, 8 is more than enough
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "assetport"
  }
}
