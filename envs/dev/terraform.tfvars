environment             = "dev"
deployment_account_id   = "PREENCHER-apos-org"
cidr                    = "10.0.0.0/16"
instance_type           = "t3.medium"
enable_network_firewall = false
stop_schedule_cron      = "cron(0 6 * * ? *)" # 03:00 BRT; ligar manualmente quando quiser
