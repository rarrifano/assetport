# ---------------------------------------------------------------------------
# IAM — EC2 Instance Profile with least-privilege S3 + ECR access
# ---------------------------------------------------------------------------

# Trust policy: only EC2 service can assume this role
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "assetport_ec2" {
  name               = "assetport-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
  description        = "Role assumed by the Assetport EC2 instance"
}

# S3 permissions: write to the assets bucket + read own objects
data "aws_iam_policy_document" "s3_assets" {
  statement {
    sid    = "PutAssets"
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
    ]

    resources = ["${aws_s3_bucket.assets.arn}/*"]
  }

  statement {
    sid       = "ListBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.assets.arn]
  }
}

resource "aws_iam_role_policy" "s3_assets" {
  name   = "assetport-s3-assets"
  role   = aws_iam_role.assetport_ec2.id
  policy = data.aws_iam_policy_document.s3_assets.json
}

# ECR permissions: pull Docker image on EC2 boot / redeploy
data "aws_iam_policy_document" "ecr_pull" {
  statement {
    sid       = "ECRAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "ECRPull"
    effect = "Allow"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
    ]
    resources = [aws_ecr_repository.assetport.arn]
  }
}

resource "aws_iam_role_policy" "ecr_pull" {
  name   = "assetport-ecr-pull"
  role   = aws_iam_role.assetport_ec2.id
  policy = data.aws_iam_policy_document.ecr_pull.json
}

# CloudWatch Logs: allow the app to write logs
resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.assetport_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Instance profile — wraps the role so EC2 can use it
resource "aws_iam_instance_profile" "assetport" {
  name = "assetport-ec2-profile"
  role = aws_iam_role.assetport_ec2.name
}

# ---------------------------------------------------------------------------
# GitHub Actions OIDC — CI/CD pushes to ECR + deploys to EC2, no long-lived keys
# ---------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "aws_iam_openid_connect_provider" "github" {
  # This assumes the GitHub OIDC provider already exists in the account.
  # If not, uncomment the resource block below and remove this data source.
  url = "https://token.actions.githubusercontent.com"
}

# Uncomment if the OIDC provider doesn't exist yet:
# resource "aws_iam_openid_connect_provider" "github" {
#   url             = "https://token.actions.githubusercontent.com"
#   client_id_list  = ["sts.amazonaws.com"]
#   thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
# }

data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      # Replace YOUR_GITHUB_ORG/YOUR_REPO with your actual repo
      values = ["repo:YOUR_GITHUB_ORG/assetport:*"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "assetport-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
  description        = "Role assumed by GitHub Actions for CI/CD"
}

data "aws_iam_policy_document" "github_actions_policy" {
  statement {
    sid       = "ECRAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "ECRPush"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = [aws_ecr_repository.assetport.arn]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "assetport-github-actions-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_policy.json
}
