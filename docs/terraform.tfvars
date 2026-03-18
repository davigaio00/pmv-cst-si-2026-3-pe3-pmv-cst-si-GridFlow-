resource_prefix = "<seu-prefixo>"

# FinOps: mantenha false por padrão para não subir NAT/EIP/Client VPN sem necessidade.
enable_expensive_resources = false

aws_region  = "us-east-1"
aws_profile = ""

# Opções recomendadas para chave pública:
# ssh_public_key = file("~/.ssh/id_ed25519.pub")
# ssh_public_key = "ssh-ed25519 AAAA... usuario@host"
ssh_public_key = "<cole-sua-chave-publica-aqui>"

# Obrigatório quando enable_expensive_resources = true
client_vpn_server_certificate_arn = "<arn-certificado-servidor-acm>"

# Obrigatório apenas para autenticação por certificado (quando SAML estiver vazio)
client_vpn_root_certificate_arn = ""

# Opcional: cole XML do metadata SAML (ou use file("idp-metadata.xml")).
# Deixe vazio para usar autenticação por certificado.
client_vpn_saml_metadata_document = ""

# Opcional
client_vpn_client_cidr = "10.0.255.0/27"
client_vpn_dns_servers = ["1.1.1.1", "1.0.0.1"]