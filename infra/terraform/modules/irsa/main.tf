data "aws_iam_policy_document" "assume_role_with_oidc" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }
  }
}

resource "aws_iam_role" "backend_irsa" {
  name               = "${var.project_name}-backend-irsa"
  assume_role_policy = data.aws_iam_policy_document.assume_role_with_oidc.json
}

resource "aws_iam_policy" "secrets_manager" {
  name = "${var.project_name}-secrets-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [var.secrets_manager_secret_arn]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "backend_secrets" {
  role       = aws_iam_role.backend_irsa.name
  policy_arn = aws_iam_policy.secrets_manager.arn
}
