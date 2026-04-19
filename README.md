# Assetport

**Mail asset upload portal — private upload, public CDN delivery.**

Upload images, HTML templates and other mail assets through a private web UI. Each file is stored in S3 and served publicly via CloudFront, giving you a stable HTTPS URL ready to paste into any email campaign tool.

---

## Quick start (local)

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt

# Without S3 — preview-only mode
streamlit run app/main.py

# With S3 — copy and fill in your values
cp .env.example .env
# edit .env, then:
AWS_REGION=... AWS_BUCKET_NAME=... CLOUDFRONT_DOMAIN=... streamlit run app/main.py
```

App opens at **http://localhost:8501**

---

## Docker

```bash
docker build -t assetport .
docker run -p 8501:8501 --env-file .env assetport
```

---

## Project structure

```
.
├── app/
│   ├── __init__.py
│   └── main.py               # Streamlit app — upload UI + S3 integration
├── tests/
│   └── test_main.py          # Unit tests
├── infra/                    # Terraform — AWS infrastructure
│   ├── main.tf               # Provider + backend config
│   ├── variables.tf
│   ├── outputs.tf
│   ├── ecr.tf                # ECR repository
│   ├── s3.tf                 # Assets bucket
│   ├── cloudfront.tf         # CDN distribution
│   ├── iam.tf                # EC2 instance profile + GitHub Actions OIDC role
│   ├── sg.tf                 # Security group
│   ├── ec2.tf                # t2.micro instance
│   └── user_data.sh          # Bootstrap script (Docker + container start)
├── .github/
│   └── workflows/
│       └── ci.yml            # Lint → test → build → push → deploy
├── Dockerfile
├── requirements.txt
├── requirements-dev.txt
├── pyproject.toml
└── .env.example
```

---

## Environment variables

| Variable             | Required | Description                                          |
| -------------------- | -------- | ---------------------------------------------------- |
| `AWS_REGION`         | Yes      | AWS region (e.g. `us-east-1`)                        |
| `AWS_BUCKET_NAME`    | Yes      | S3 bucket name for uploaded assets                   |
| `CLOUDFRONT_DOMAIN`  | Yes      | CloudFront base URL (e.g. `https://abc.cloudfront.net`) |

> On EC2 with an IAM Instance Profile, `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` are **not needed** — credentials are provided automatically.

---

## Development

```bash
ruff check .          # lint
ruff format .         # format
mypy app/             # type check
pytest                # run tests
```

---

## Infrastructure (Terraform)

### Prerequisites
- AWS CLI configured (`aws configure`)
- Terraform ≥ 1.7
- Your SSH public key ready
- Your public IP (`curl ifconfig.me`)

### Deploy

```bash
cd infra

terraform init

terraform apply \
  -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)" \
  -var="allowed_cidr=$(curl -s ifconfig.me)/32"
```

Terraform will output:

| Output               | Description                                  |
| -------------------- | -------------------------------------------- |
| `app_url`            | Direct URL to the upload app on EC2          |
| `cloudfront_domain`  | Base URL for all public asset links          |
| `s3_bucket_name`     | Bucket where assets are stored               |
| `ecr_repository_url` | ECR repo URL for CI/CD image pushes          |

### Destroy (free-tier cleanup)

```bash
terraform destroy
```

---

## CI/CD (GitHub Actions)

| Job              | Trigger        | What it does                                    |
| ---------------- | -------------- | ----------------------------------------------- |
| `lint-and-test`  | push + PR      | ruff, mypy, pytest                              |
| `build-and-push` | push to main   | docker build → push to ECR (OIDC, no keys)      |
| `deploy`         | after push     | SSH into EC2 → docker pull → restart container  |

### Required GitHub secrets

| Secret                         | Value                                              |
| ------------------------------ | -------------------------------------------------- |
| `AWS_GITHUB_ACTIONS_ROLE_ARN`  | ARN of the `assetport-github-actions` IAM role     |
| `EC2_HOST`                     | Public IP of the EC2 instance (from Terraform output) |
| `EC2_SSH_PRIVATE_KEY`          | Private key matching the public key used in Terraform |

---

## Architecture

```
Browser (your IP only)
        │ :8501
        ▼
EC2 t2.micro  ──boto3──►  S3 Bucket (private)
(Docker/Streamlit)              │
        │               per-object public-read ACL
        │                       │
        │               CloudFront CDN
        │                       │
        └── returns ────► Public HTTPS URL
                          (paste into email campaign)
```

### Key decisions

| Decision                         | Rationale                                                                                     |
| -------------------------------- | --------------------------------------------------------------------------------------------- |
| **EC2 over ECS Fargate**         | Free-tier eligible. Upgrade path to Fargate is a swap of `ec2.tf` → `ecs.tf`, nothing else changes. |
| **No ALB**                       | ALB costs ~$16/mo minimum — not free tier. Port 8501 locked to your IP via security group.   |
| **IAM Instance Profile**         | EC2 inherits S3 permissions from the role — no AWS keys stored anywhere.                     |
| **GitHub OIDC (no keys)**        | Short-lived tokens via OIDC federation — no long-lived `AWS_ACCESS_KEY_ID` in GitHub secrets.|
| **S3 private + per-object ACL**  | Bucket is private by default. App sets `public-read` ACL per object on upload.               |
| **CloudFront OAC**               | CloudFront reads S3 privately via Origin Access Control — S3 bucket has no public URL.       |
| **S3 versioning ON**             | Protects against accidental overwrites of assets already used in live campaigns.             |
| **Preview-only mode**            | If env vars are missing the app still works locally — shows a warning, skips S3 upload.      |
