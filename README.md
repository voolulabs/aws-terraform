# aws-terraform — fundação IaC/GitOps da solução SaaS (voolulabs)

Infraestrutura AWS como código da solução SaaS, com GitOps (GitHub Actions +
OIDC + roles separadas de plan/apply). Base: template oficial
`aws-samples/aws-terraform-template`. Região única **sa-east-1** (decisão do
dono, 2026-10-11).

## Arquitetura

```
bootstrap/   one-time: bucket de estado (KMS+versioning+lockfile) — estado LOCAL
org/         conta de gestão: Organizations (contas dev/test/prod), CloudTrail
             organizacional, IAM Identity Center (humanos), roles de CI (OIDC
             GitHub) e role de agente IA — estado S3
modules/     network (VPC+SG+firewall-optional), compute (EC2+ECR+schedule),
             storage (S3 assets/logs)
envs/        dev/ test/ prod/ — um root module por ambiente, aplicado pelo CI
             assumindo OrganizationAccountAccessRole na conta membro
```

Decisões registradas do dono (2026-10-11): região única sa-east-1; AWS
Organizations **desde o início**; Network Firewall **somente no prod**;
instâncias dev/test com **stop noturno** (power-on manual quando quiser — o
schedule só desliga); Identity Center para humanos (o root fica restrito a
tarefas exclusivas, com MFA obrigatório).

## Ordem de execução (primeira vez)

```bash
# 0) Preencher os PREENCHER nos tfvars: emails únicos das 3 contas membro
#    (org/variables.tf) e o usuário do dono (org/identity_center.tf).

# 1) bootstrap (uma vez, com `aws login` root; estado local)
cd bootstrap && terraform init && terraform apply

# 2) org (local, na conta de gestão; estado S3)
cd ../org && terraform init && terraform apply       # identity_center_enabled=false
# 2b) No console: habilitar IAM Identity Center na região sa-east-1
#     (ação única; cria a instância que o Terraform passa a administrar).
# 2c) Preencher os ARNs no GitHub (secrets do repo — ver tabela abaixo) e
#     os IDs de conta em envs/*/terraform.tfvars (outputs do org/).
# 2d) Re-aplicar org com -var identity_center_enabled=true
cd ../org && terraform apply -var identity_center_enabled=true

# 3) Ambientes: 100% GitOps — PR roda plan (roles de plan); merge em main
#    aplica dev -> test -> prod (prod com approval do environment no GitHub).
```

## Secrets do GitHub (após o org/)

| Secret | Valor (output do `org/`) |
|---|---|
| `ORG_APPLY_ROLE_ARN` | `ci_org_role_arn` |
| `DEV_AWS_PLAN_ROLE_ARN` / `DEV_AWS_APPLY_ROLE_ARN` | `ci_plan_role_arn` / `ci_apply_role_arn` (o apply entra na conta membro via OrganizationAccountAccessRole) |
| `TEST_AWS_PLAN_ROLE_ARN` / `TEST_AWS_APPLY_ROLE_ARN` | idem |
| `PROD_AWS_PLAN_ROLE_ARN` / `PROD_AWS_APPLY_ROLE_ARN` | idem |

Proteções de repo recomendadas: branch protection em `main` (CODEOWNERS),
GitHub environments `test` (sem approval) e `prod` (**required reviewers**),
`org-management` (required reviewers).

## Operação

- **Power-on da instância** (após o stop noturno): via console (EC2 → Start) ou
  `aws ec2 start-instances --instance-ids <id> --region sa-east-1`. O schedule
  desliga diariamente às 03:00 BRT; nunca liga sozinho.
- **Acesso à instância**: somente SSM Session Manager (sem SSH aberto).
- **Imagens do backend**: ECR por ambiente (`<env>/pos-backend`), publicado
  pelo pipeline do repo da aplicação.

## Guardas

- Estado em S3 (KMS + versioning + lockfile nativo), trilha CloudTrail
  organizacional, roles plan/apply separadas com conditions no OIDC
  (repo/branch/environment), MFA para humanos, `prevent_destroy` nas contas
  membro.
- Segredos de aplicação (credenciais de adquirente, MP etc.) **não** passam
  por este repo — vivem no secret store da aplicação.
