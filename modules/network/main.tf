module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.16"

  name = var.name
  cidr = var.cidr

  azs             = var.azs
  public_subnets  = [for i, az in var.azs : cidrsubnet(var.cidr, 4, i)]
  private_subnets = [for i, az in var.azs : cidrsubnet(var.cidr, 4, i + length(var.azs))]

  # NAT: dev com gateway único (custo), test/prod com um por AZ.
  enable_nat_gateway     = true
  single_nat_gateway     = var.environment == "dev"
  one_nat_gateway_per_az = var.environment != "dev"

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = var.environment
  }
}

# Baseline de acesso público do stack de homologação (http do app de caixa e
# storefront). SSH não existe: acesso à instância é exclusivamente via SSM.
resource "aws_security_group" "public_stack" {
  name_prefix = "${var.name}-public"
  description = "Portas do stack de homologacao POS"
  vpc_id      = module.vpc.vpc_id

  dynamic "ingress" {
    for_each = toset([9000, 8000])
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = var.public_ingress_cidrs
      description = "http stack POS"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Egress amplo (pacotes, imagens, APIs)"
  }

  tags = {
    Name        = "${var.name}-public"
    Environment = var.environment
  }
}

# Network Firewall (somente prod): subnets dedicadas de inspeção + firewall +
# policy stateful padrão de deny-doméstico. Desligado por variável nos demais.
locals {
  firewall_enabled = var.enable_network_firewall
}

resource "aws_subnet" "firewall" {
  for_each = local.firewall_enabled ? toset(var.azs) : toset([])

  vpc_id            = module.vpc.vpc_id
  cidr_block        = cidrsubnet(var.cidr, 4, 8 + index(var.azs, each.value))
  availability_zone = each.value

  tags = { Name = "${var.name}-firewall-${each.value}" }
}

module "network_firewall" {
  count = local.firewall_enabled ? 1 : 0

  source  = "terraform-aws-modules/network-firewall/aws"
  version = "~> 1.0"

  name        = "${var.name}-fw"
  description = "Firewall de rede do ambiente prod (decisao do dono: so no prod)"
  vpc_id      = module.vpc.vpc_id

  subnet_mapping = {
    for i, az in var.azs : az => {
      subnet_id       = aws_subnet.firewall[az].id
      ip_address_type = "IPV4"
    }
  }

  policy_name                               = "${var.name}-fw-policy"
  policy_stateful_default_actions           = ["aws:drop_strict"]
  policy_stateless_default_actions          = ["aws:pass"]
  policy_stateless_fragment_default_actions = ["aws:drop"]

  tags = { Environment = var.environment }
}
