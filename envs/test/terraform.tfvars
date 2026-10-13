environment             = "test"
deployment_account_id   = "781504635766" # TEMPORARIO ate o case abrir
assume_deployment_role   = false
cidr                    = "10.1.0.0/16"
instance_type           = "t3.medium"
enable_network_firewall = false
stop_schedule_cron      = "cron(0 6 * * ? *)" # 03:00 BRT; homologação ligada sob demanda
