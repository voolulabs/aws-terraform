output "account_ids" {
  description = "IDs das contas membro por ambiente — valores para os secrets *_AWS_PLAN_ROLE_ARN / *_AWS_APPLY_ROLE_ARN e para os tfvars dos envs"
  value       = { for k, a in aws_organizations_account.env : k => a.id }
}

output "management_account_id" {
  description = "Conta de gestão (Organizations; sem workloads)"
  value       = data.aws_caller_identity.current.account_id
}

output "ci_plan_role_arn" {
  description = "Role assumida pelo GitHub Actions para plan"
  value       = aws_iam_role.ci_plan.arn
}

output "ci_apply_role_arn" {
  description = "Role assumida pelo GitHub Actions para apply"
  value       = aws_iam_role.ci_apply.arn
}

output "ci_org_role_arn" {
  description = "Role para o dispatch manual do stack org/ via CI"
  value       = aws_iam_role.ci_org.arn
}

output "ai_agent_role_arn" {
  description = "Role do agente IA (MCP/STS) na conta de gestão"
  value       = aws_iam_role.ai_agent.arn
}

output "member_deployment_role" {
  description = "Role de deploy que existe em cada conta membro"
  value       = "OrganizationAccountAccessRole"
}
