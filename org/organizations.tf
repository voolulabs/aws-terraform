# Conta de gestão (781504635766) vira o management do Organizations: sem
# workloads, só billing, SCPs e a âncora de identidade. Contas membro criadas
# aqui assumem workloads (dev/test/prod).
resource "aws_organizations_organization" "main" {
  feature_set                   = "ALL"
  aws_service_access_principals = ["cloudtrail.amazonaws.com", "sso.amazonaws.com"]
  enabled_policy_types          = [] # SCPs entram quando houver necessidade real (lean)
}

# Uma conta membro por ambiente. O email é o único identificador obrigatório
# e precisa ser ÚNICO na AWS inteira (usar aliases do domínio do dono).
# role_name padrão: OrganizationAccountAccessRole (admin na membro, assumido
# pela gestão — é por ele que o CI e os humanos operam os ambientes).
resource "aws_organizations_account" "env" {
  for_each  = var.account_emails
  name      = "voolulabs-pos-${each.key}"
  email     = each.value
  role_name = "OrganizationAccountAccessRole"

  parent_id = aws_organizations_organizational_unit.envs[each.key].id

  # Guarda contra criação concorrente parcial (melhor prática do provider):
  # o provider gerencia a abertura, o close depende de processo manual.
  lifecycle {
    prevent_destroy = true
  }
}

# OUs: uma por ambiente — base para SCPs por ambiente no futuro.
resource "aws_organizations_organizational_unit" "envs" {
  for_each  = var.account_emails
  name      = each.key
  parent_id = aws_organizations_organization.main.roots[0].id
}
