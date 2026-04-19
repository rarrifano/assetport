# ---------------------------------------------------------------------------
# ECR repository — stores the Docker image
# ---------------------------------------------------------------------------
resource "aws_ecr_repository" "assetport" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "assetport"
  }
}

# Keep only the last 5 images to save ECR storage costs
resource "aws_ecr_lifecycle_policy" "assetport" {
  repository = aws_ecr_repository.assetport.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = { type = "expire" }
    }]
  })
}
