# ---------------------------------------------------------------------------
# Security Group — controls inbound access to the EC2 instance
# ---------------------------------------------------------------------------

# Fetch default VPC — used for free-tier simplicity
data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "assetport" {
  name        = "assetport-sg"
  description = "Assetport EC2: allow SSH from your IP, app from your IP, all outbound"
  vpc_id      = data.aws_vpc.default.id

  # SSH — restricted to your IP
  ingress {
    description = "SSH from allowed CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # Streamlit app — restricted to your IP
  ingress {
    description = "Streamlit app from allowed CIDR"
    from_port   = 8501
    to_port     = 8501
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # All outbound — needed for ECR pull, S3 uploads, package installs
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "assetport-sg"
  }
}
