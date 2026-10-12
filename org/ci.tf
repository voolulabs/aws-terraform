# Identidades de máquina (CI/CD): GitHub Actions assume roles da conta de
# gestão via OIDC; o apply entra nas contas membro assumindo a
# OrganizationAccountAccessRole criada com cada conta. Plan = somente leitura.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

locals {
  github_conditions = {
    repo = var.github_repo
  }
}

# Trust POR ROLE (revisão adversarial 2026-10-12): plan aceita pull_request;
# apply e org exigem o claim de environment do job (os events de PR/push sem
# environment não passam) — a comporta vive no IAM, não só no YAML do workflow.
data "aws_iam_policy_document" "ci_trust_plan" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repo}:ref:refs/heads/main",
        "repo:${var.github_repo}:pull_request",
      ]
    }
  }
}

data "aws_iam_policy_document" "ci_trust_apply" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:environment:*"]
    }
  }
}

data "aws_iam_policy_document" "ci_trust_org" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:environment:org-management"]
    }
  }
}

resource "aws_iam_role" "ci_plan" {
  name                 = "github-terraform-plan"
  assume_role_policy   = data.aws_iam_policy_document.ci_trust_plan.json
  max_session_duration = 3600

  tags = { Stack = "org", Tipo = "maquina-ci" }
}

resource "aws_iam_role" "ci_apply" {
  name                 = "github-terraform-apply"
  assume_role_policy   = data.aws_iam_policy_document.ci_trust_apply.json
  max_session_duration = 14400

  tags = { Stack = "org", Tipo = "maquina-ci" }
}

# PLAN: leitura ampla (ReadOnly) + acesso de leitura ao estado + KMS.
resource "aws_iam_role_policy_attachment" "ci_plan_readonly" {
  role       = aws_iam_role.ci_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "ci_plan_state" {
  # O provider dos envs assume a OrganizationAccountAccessRole da conta membro:
  # o plan precisa de sts:AssumeRole (ReadOnlyAccess não inclui).
  statement {
    actions   = ["sts:AssumeRole"]
    resources = [for k, a in aws_organizations_account.env : "arn:aws:iam::${a.id}:role/OrganizationAccountAccessRole"]
  }
  statement {
    actions   = ["s3:ListBucket", "s3:GetObject"]
    resources = ["arn:aws:s3:::${var.state_bucket_name}", "arn:aws:s3:::${var.state_bucket_name}/*"]
  }
  statement {
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = ["arn:aws:kms:${var.region}:${data.aws_caller_identity.current.account_id}:key/*"]
    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values   = ["s3.${var.region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "ci_plan_state" {
  role   = aws_iam_role.ci_plan.id
  policy = data.aws_iam_policy_document.ci_plan_state.json
}

# APPLY: assume a OrganizationAccountAccessRole das contas membro + escreve o
# estado. Nada de admin direto na conta de gestão.
data "aws_iam_policy_document" "ci_apply" {
  statement {
    actions   = ["sts:AssumeRole"]
    resources = [for k, a in aws_organizations_account.env : "arn:aws:iam::${a.id}:role/OrganizationAccountAccessRole"]
  }
  statement {
    actions = [
      "s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
    ]
    resources = ["arn:aws:s3:::${var.state_bucket_name}", "arn:aws:s3:::${var.state_bucket_name}/*"]
  }
  statement {
    actions   = ["kms:Decrypt", "kms:DescribeKey", "kms:GenerateDataKey"]
    resources = ["arn:aws:kms:${var.region}:${data.aws_caller_identity.current.account_id}:key/*"]
    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values   = ["s3.${var.region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "ci_apply" {
  role   = aws_iam_role.ci_apply.id
  policy = data.aws_iam_policy_document.ci_apply.json
}

# Role para o dispatch MANUAL do stack org/ pelo CI (workflow_dispatch):
# administra a conta de gestão (Organizations, Identity Center, CloudTrail).
resource "aws_iam_role" "ci_org" {
  name                 = "github-terraform-org"
  assume_role_policy   = data.aws_iam_policy_document.ci_trust_org.json
  max_session_duration = 7200

  tags = { Stack = "org", Tipo = "maquina-ci" }
}

resource "aws_iam_role_policy_attachment" "ci_org_admin" {
  role       = aws_iam_role.ci_org.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Identidade de agente IA (o consentimento OAuth do AWS MCP sairá do root para
# cá quando o Identity Center estiver ativo; leitura por padrão, ação só com
# a condition key do MCP para auditoria separada no CloudTrail).
resource "aws_iam_role" "ai_agent" {
  name = "ai-agent-pos"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = ["sts:AssumeRole", "sts:TagSession"]
      Principal = { AWS = data.aws_caller_identity.current.account_id }
      Condition = { Bool = { "aws:multifactorauthpresent" = "true" } }
    }]
  })
  max_session_duration = 3600

  tags = { Stack = "org", Tipo = "agente-ia" }
}

resource "aws_iam_role_policy_attachment" "ai_agent_readonly" {
  role       = aws_iam_role.ai_agent.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "ai_agent_mcp" {
  role = aws_iam_role.ai_agent.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["signin:AuthorizeOAuth2Access", "signin:CreateOAuth2Token"]
      Resource = "arn:aws:signin:*:*:service-principal/aws-mcp.amazonaws.com"
    }]
  })
}
