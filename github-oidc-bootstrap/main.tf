data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_trust" {
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
      values   = ["repo:${var.github_repository_username}*/${var.github_repository_name}*:*"]
    }
  }
}

resource "aws_iam_role" "github_oidc" {
  name               = var.github_oidc_role_name
  assume_role_policy = data.aws_iam_policy_document.github_trust.json
}


# 1. Consolidated AWS Managed Policies for Core Services
resource "aws_iam_role_policy_attachment" "managed_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/AmazonRoute53FullAccess",
    "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess",
    "arn:aws:iam::aws:policy/AmazonAPIGatewayAdministrator",
    "arn:aws:iam::aws:policy/AWSCertificateManagerFullAccess",
    "arn:aws:iam::aws:policy/AWSLambda_FullAccess",
    "arn:aws:iam::aws:policy/AWSWAFFullAccess"
  ])

  role       = aws_iam_role.github_oidc.name
  policy_arn = each.value
}

# 2. Custom Inline Policy for IAM Role Creation, PassRole, and WAF CloudWatch Logs
data "aws_iam_policy_document" "deployment_extra_permissions" {
  statement {
    sid    = "IAMPassRoleAndRoleLifecycle"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:GetRole",
      "iam:DeleteRole",
      "iam:PutRolePolicy",
      "iam:GetRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListInstanceProfilesForRole", # <-- Required by Terraform to delete roles
      "iam:PassRole",
      "iam:TagRole"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchLogsForWAF"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:DescribeLogGroups",
      "logs:PutRetentionPolicy",
      "logs:DeleteRetentionPolicy",
      "logs:ListTagsForResource",
      "logs:TagResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CertificateAndHostedZoneLookups"
    effect = "Allow"
    actions = [
      "acm:DescribeCertificate",
      "acm:ListCertificates",
      "route53:GetHostedZone",
      "route53:ListHostedZones"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "extra_permissions" {
  name   = "pipeline-extra-deployment-permissions"
  role   = aws_iam_role.github_oidc.name
  policy = data.aws_iam_policy_document.deployment_extra_permissions.json
}

variable "github_repository_username" {
  description = "GitHub repository username"
  type        = string
  default     = "eugenewongyj"
}

variable "github_repository_name" {
  description = "GitHub repository name"
  type        = string
  default     = "cloud-ntu-coaching16"
}

variable "github_oidc_role_name" {
  description = "Name of the GitHub OIDC role"
  type        = string
  default     = "group2-coaching16-github-oidc-role"
}

output "github_oidc_role_arn" {
  value = aws_iam_role.github_oidc.arn
}