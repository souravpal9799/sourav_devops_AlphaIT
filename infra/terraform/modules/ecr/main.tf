resource "aws_ecr_repository" "frontend" {
  name = "frontend-app"
  force_delete = true
}

resource "aws_ecr_repository" "backend" {
  name = "backend-app"
  force_delete = true
}
