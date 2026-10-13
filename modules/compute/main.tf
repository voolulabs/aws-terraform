# Host do stack POS (docker compose da store-b2c). Sem SSH: acesso exclusivo
# via SSM Session Manager. Docker instalado no boot por cloud-init.
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_iam_role" "instance" {
  name_prefix = "${var.name}-ec2-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Environment = var.environment, Tipo = "maquina" }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy" "assets_read" {
  count = var.enable_assets_access ? 1 : 0

  role = aws_iam_role.instance.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = ["s3:GetObject", "s3:ListBucket"]
      Resources = [var.assets_bucket_arn, "${var.assets_bucket_arn}/*"]
    }]
  })
}

resource "aws_iam_instance_profile" "main" {
  name = "${var.name}-ec2-profile"
  role = aws_iam_role.instance.name
}

# Imagens do stack (backend Medusa + storefront) publicadas pelo pipeline do
# repo da aplicação; o host faz pull via role, nunca com credencial local.
resource "aws_ecr_repository" "app" {
  name                 = "${var.name}/pos-backend"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Environment = var.environment }
}

module "ec2" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 6.4"

  name = "${var.name}-pos-stack"

  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.public_stack_sg_id]
  associate_public_ip_address = var.associate_public_ip
  iam_instance_profile        = aws_iam_instance_profile.main.name

  user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail
    dnf update -y
    dnf install -y docker
    systemctl enable --now docker
    usermod -aG docker ec2-user
    mkdir -p /opt/pos
  EOT

  metadata_options = {
    http_tokens = "required" # IMDSv2
  }

  root_block_device = {
    encrypted = true
    size      = 30
    type      = "gp3"
  }

  tags = {
    Environment = var.environment
    Stack       = "pos"
  }
}

# Desligamento noturno (decisão do dono): o schedule só STOPA — ligar quando
# quiser é manual (console/CLI/SSM), sem workflow de start que engessa custo.
data "archive_file" "stop_lambda" {
  count = var.stop_schedule_cron != "" ? 1 : 0

  type        = "zip"
  output_path = "${path.module}/.build/stop_lambda.zip"
  source {
    content  = <<-PY
      import boto3, json, os
      def handler(event, context):
          ec2 = boto3.client("ec2")
          res = ec2.describe_instances(
              Filters=[{"Name": "tag:Stack", "Values": ["pos"]},
                       {"Name": "instance-state-name", "Values": ["running"]}])
          ids = [i["InstanceId"] for r in res["Reservations"] for i in r["Instances"]]
          if ids:
              ec2.stop_instances(InstanceIds=ids)
          return {"stopped": ids}
    PY
    filename = "lambda.py"
  }
}

# Duas roles (revisão adversarial 2026-10-12): execução da Lambda exige trust
# de lambda.amazonaws.com; o Scheduler precisa de uma role invocadora própria
# com lambda:InvokeFunction. Uma role única com os dois principals não serve —
# cada serviço valida o trust do papel que exerce.
resource "aws_iam_role" "stop_exec" {
  count = var.stop_schedule_cron != "" ? 1 : 0

  name = "${var.name}-stop-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "stop_exec" {
  count = var.stop_schedule_cron != "" ? 1 : 0

  role = aws_iam_role.stop_exec[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ec2:StopInstances", "ec2:DescribeInstances"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
    ]
  })
}

resource "aws_iam_role" "stop_invoker" {
  count = var.stop_schedule_cron != "" ? 1 : 0

  name = "${var.name}-stop-invoker"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "stop_invoker" {
  count = var.stop_schedule_cron != "" ? 1 : 0

  role = aws_iam_role.stop_invoker[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = [aws_lambda_function.stop[0].arn]
    }]
  })
}

resource "aws_lambda_function" "stop" {
  count = var.stop_schedule_cron != "" ? 1 : 0

  function_name    = "${var.name}-ec2-stop"
  role             = aws_iam_role.stop_exec[0].arn
  runtime          = "python3.13"
  handler          = "lambda.handler"
  filename         = data.archive_file.stop_lambda[0].output_path
  source_code_hash = data.archive_file.stop_lambda[0].output_base64sha256
  timeout          = 60

  tags = { Environment = var.environment }
}

resource "aws_scheduler_schedule" "nightly_stop" {
  count = var.stop_schedule_cron != "" ? 1 : 0

  name = "${var.name}-ec2-stop"
  flexible_time_window {
    mode = "OFF"
  }
  schedule_expression = var.stop_schedule_cron

  target {
    arn      = aws_lambda_function.stop[0].arn
    role_arn = aws_iam_role.stop_invoker[0].arn
  }
}
