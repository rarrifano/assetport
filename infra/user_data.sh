#!/bin/bash
# ---------------------------------------------------------------------------
# Assetport — EC2 bootstrap script (runs once on first boot via cloud-init)
# Installs Docker, authenticates to ECR, pulls and starts the app container.
# ---------------------------------------------------------------------------
set -euo pipefail

AWS_REGION="${aws_region}"
ECR_REPO_URL="${ecr_repo_url}"
BUCKET_NAME="${bucket_name}"
CLOUDFRONT_DOMAIN="${cloudfront_domain}"
APP_ENV_FILE="/etc/assetport.env"

# ---------------------------------------------------------------------------
# 1. System updates + Docker
# ---------------------------------------------------------------------------
dnf update -y
dnf install -y docker aws-cli

systemctl enable docker
systemctl start docker

# Allow ec2-user to run docker without sudo
usermod -aG docker ec2-user

# ---------------------------------------------------------------------------
# 2. Write app environment file (no secrets — all resolved via IAM role)
# ---------------------------------------------------------------------------
cat > "$APP_ENV_FILE" <<EOF
AWS_REGION=$AWS_REGION
AWS_BUCKET_NAME=$BUCKET_NAME
CLOUDFRONT_DOMAIN=$CLOUDFRONT_DOMAIN
EOF
chmod 600 "$APP_ENV_FILE"

# ---------------------------------------------------------------------------
# 3. Authenticate to ECR and pull the latest image
# ---------------------------------------------------------------------------
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REPO_URL"

docker pull "$ECR_REPO_URL:latest"

# ---------------------------------------------------------------------------
# 4. Run the container (restart always = survives reboots)
# ---------------------------------------------------------------------------
docker run -d \
  --name assetport \
  --restart always \
  --env-file "$APP_ENV_FILE" \
  -p 8501:8501 \
  "$ECR_REPO_URL:latest"

# ---------------------------------------------------------------------------
# 5. Create a systemd service so the container starts on future reboots
#    even if Docker daemon restarts before cloud-init
# ---------------------------------------------------------------------------
cat > /etc/systemd/system/assetport.service <<'UNIT'
[Unit]
Description=Assetport Streamlit container
After=docker.service
Requires=docker.service

[Service]
Restart=always
ExecStart=/usr/bin/docker start -a assetport
ExecStop=/usr/bin/docker stop assetport

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable assetport
