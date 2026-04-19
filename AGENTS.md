# AGENTS.md

Compact ramp-up guide for OpenCode sessions in this repo.

## Project

**Assetport** — Streamlit drag-and-drop upload portal.  
Files are stored in a private S3 bucket and served publicly via CloudFront.  
The app runs in a Docker container on an EC2 `t2.micro` (free-tier).

## Repo layout

```
app/main.py          # single-file Streamlit app — entrypoint
app/static/          # static assets (no logo — header is pure HTML/CSS in main.py)
tests/test_main.py   # all unit tests live here
infra/               # Terraform — one .tf file per AWS resource
.github/workflows/ci.yml  # CI (lint+test) + CD (ECR push + SSH deploy)
```

## Developer commands

Always run in this order — CI enforces the same sequence:

```bash
# 1. lint (auto-fix)
.venv/bin/ruff check . --fix

# 2. format
.venv/bin/ruff format .

# 3. type check
.venv/bin/mypy app/

# 4. tests
.venv/bin/pytest                          # all tests
.venv/bin/pytest tests/test_main.py::test_upload_to_s3_returns_public_url  # single test
```

One-liner used in CI:
```bash
ruff check . --fix && ruff format . && mypy app/ && pytest tests/ -v --cov=app
```

## Toolchain quirks

- **Python target is 3.12** (`pyproject.toml`) but the local venv may run 3.14 — `mypy` is configured for 3.12 so type errors are evaluated against that version.
- **ruff line-length is 88**. Inline HTML strings inside `st.markdown()` must be split into variables to stay under the limit (see `render_header()` in `app/main.py`).
- **mypy strict mode is ON** — all functions need return types and typed arguments, `Any` must be imported explicitly.
- `boto3` calls must be wrapped in `except (BotoCoreError, ClientError)` — bare `Exception` will fail mypy strict.

## S3 / AWS integration

- The app runs in **preview-only mode** when `AWS_BUCKET_NAME` or `CLOUDFRONT_DOMAIN` env vars are unset — no error, just a warning banner. Never remove this fallback.
- On EC2, credentials come from the **IAM Instance Profile** — no `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` needed or wanted.
- `upload_to_s3()` sets `ACL: public-read` per object. The bucket itself blocks public policies — only per-object ACLs are allowed (`block_public_acls = false`, `block_public_policy = true` in `infra/s3.tf`).
- The public URL pattern is `{CLOUDFRONT_DOMAIN}/{file.name}` — no path prefix, flat namespace.

## Terraform (infra/)

- One resource type per file: `ecr.tf`, `s3.tf`, `cloudfront.tf`, `iam.tf`, `sg.tf`, `ec2.tf`.
- `user_data.sh` is a `templatefile()` — variables injected: `aws_region`, `ecr_repo_url`, `bucket_name`, `cloudfront_domain`.
- The GitHub OIDC provider (`aws_iam_openid_connect_provider.github`) is a **data source** — it must already exist in the AWS account. There is a commented-out `resource` block in `iam.tf` to create it if missing.
- `var.cloudfront_domain_alias` is optional — leave empty to use the default CloudFront domain; the `viewer_certificate` block switches automatically.
- No ALB — port 8501 is exposed directly, locked to `var.allowed_cidr`. This is intentional (free-tier, no $16/mo ALB charge).

## CI/CD

- **OIDC only** — no long-lived AWS keys. The `build-and-push` and `deploy` jobs require `permissions: id-token: write`.
- Deploy job uses `appleboy/ssh-action` — re-authenticates to ECR on the EC2 instance before pulling.
- Required GitHub secrets: `AWS_GITHUB_ACTIONS_ROLE_ARN`, `EC2_HOST`, `EC2_SSH_PRIVATE_KEY`.
- CI does **not** run `terraform` — infra is applied manually by the operator.

## Testing conventions

- All tests are in `tests/test_main.py` — no subdirectories.
- S3/boto3 calls are mocked with `unittest.mock.patch("app.main.boto3.client")`.
- `monkeypatch` is used to override module-level constants (`AWS_BUCKET_NAME`, `CLOUDFRONT_DOMAIN`, `AWS_REGION`) — patch the attribute on `app.main`, not on `os.environ`.
- `st.*` calls that would error outside a Streamlit session (e.g. `st.error`) must also be patched in tests that trigger them.

## What not to do

- Do not add a logo image or reference `app/static/logo.png` — the header is intentional pure HTML/CSS in `render_header()`.
- Do not mention "Prime Energy" or any company name anywhere in source, config, or docs.
- Do not store AWS credentials in env files, Docker images, or GitHub secrets — IAM roles only.
- Do not create an ALB in Terraform — the free-tier design intentionally omits it.
