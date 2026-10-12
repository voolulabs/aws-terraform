# Identidade humana via IAM Identity Center (decisão 2026-10-11: Organizations
# agora => Identity Center em vez de IAM users por conta). O Identity Center
# precisa ser HABILITADO uma vez no console (região home sa-east-1 — decisão
# única da instância) antes do primeiro apply com identity_center_enabled=true.
# Fluxo: apply org (false) -> habilitar no console -> re-apply (true).
locals {
  identity_center = var.identity_center_enabled ? one(data.aws_ssoadmin_instances.main[*].identity_store_ids) : null
}

data "aws_ssoadmin_instances" "main" {
  count = var.identity_center_enabled ? 1 : 0
}

data "aws_caller_identity" "current" {}

resource "aws_identitystore_group" "admins" {
  count = var.identity_center_enabled ? 1 : 0

  identity_store_id = local.identity_center
  display_name      = "aws-admins"
  description       = "Administradores da conta (MFA obrigatório no console)"
}

resource "aws_identitystore_group" "developers" {
  count = var.identity_center_enabled ? 1 : 0

  identity_store_id = local.identity_center
  display_name      = "aws-developers"
  description       = "Devs: PowerUser em dev/test, leitura em prod"
}

resource "aws_identitystore_user" "owner" {
  count = var.identity_center_enabled ? 1 : 0

  identity_store_id = local.identity_center
  user_name         = var.owner_user_name
  display_name      = var.owner_display_name
  name {
    given_name  = var.owner_given_name
    family_name = var.owner_family_name
  }
  emails {
    value   = var.owner_email
    primary = true
  }
}

resource "aws_identitystore_group_membership" "owner_admin" {
  count = var.identity_center_enabled ? 1 : 0

  identity_store_id = local.identity_center
  group_id          = aws_identitystore_group.admins[0].group_id
  member_id         = aws_identitystore_user.owner[0].user_id
}

# Permission sets: o que cada grupo pode fazer em cada conta membro.
resource "aws_ssoadmin_permission_set" "administrator" {
  count = var.identity_center_enabled ? 1 : 0

  instance_arn     = local.identity_center
  name             = "AdministratorAccess"
  session_duration = "PT4H"
}

resource "aws_ssoadmin_managed_policy_attachment" "administrator" {
  count = var.identity_center_enabled ? 1 : 0

  instance_arn       = local.identity_center
  permission_set_arn = aws_ssoadmin_permission_set.administrator[0].arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_ssoadmin_permission_set" "developer" {
  count = var.identity_center_enabled ? 1 : 0

  instance_arn     = local.identity_center
  name             = "DeveloperPowerUser"
  session_duration = "PT12H"
}

resource "aws_ssoadmin_managed_policy_attachment" "developer" {
  count = var.identity_center_enabled ? 1 : 0

  instance_arn       = local.identity_center
  permission_set_arn = aws_ssoadmin_permission_set.developer[0].arn
  managed_policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# Admins em todas as contas (gestão + membros); devs só em dev/test.
# Gate via for_each (vazio quando o Identity Center não está habilitado —
# primeiro apply): count e for_each são mutuamente exclusivos no Terraform.
resource "aws_ssoadmin_account_assignment" "admins_all" {
  for_each = var.identity_center_enabled ? toset(concat([data.aws_caller_identity.current.account_id], [for k, a in aws_organizations_account.env : a.id])) : toset([])

  instance_arn       = local.identity_center
  permission_set_arn = aws_ssoadmin_permission_set.administrator[0].arn
  principal_id       = aws_identitystore_group.admins[0].group_id
  principal_type     = "GROUP"
  target_id          = each.value
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "developers_env" {
  for_each = var.identity_center_enabled ? toset([aws_organizations_account.env["dev"].id, aws_organizations_account.env["test"].id]) : toset([])

  instance_arn       = local.identity_center
  permission_set_arn = aws_ssoadmin_permission_set.developer[0].arn
  principal_id       = aws_identitystore_group.developers[0].group_id
  principal_type     = "GROUP"
  target_id          = each.value
  target_type        = "AWS_ACCOUNT"
}
