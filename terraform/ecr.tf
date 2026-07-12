# =====================================================================
# ECR — private container registry for the app image.
# Same thing you built in Sprint 1 with `aws ecr create-repository`,
# now as reproducible, version-controlled code.
# =====================================================================

resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-app" # herovire-app
  image_tag_mutability = "MUTABLE"                 # allow :latest to be overwritten
  force_delete         = true                      # let `terraform destroy` remove it even with images inside

  # Scan images for vulnerabilities on every push (free, security best practice).
  image_scanning_configuration {
    scan_on_push = true
  }

  # Encrypt stored images at rest.
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = { Name = "${var.project_name}-app" }
}

# Lifecycle policy — auto-delete untagged images after 1 day to keep
# storage lean (cost optimization). Same policy as Sprint 1, but as code.
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      }
    ]
  })
}
