# Implantação de Zero Trust na AWS

> Este repositório está em formato de **template**. Antes de executar, é necessário que sejam preenchidos os valores no arquivo `terraform.tfvars`.

Este workspace provisiona um perímetro de Zero Trust totalmente nativo da AWS, que inclui:
- Uma VPC dedicada com sub-redes públicas e privadas, NAT Gateway e instâncias bastion endurecidas (hardened) para Windows e Linux.
- Endpoints de Client VPN que alternam entre autenticação via IAM Identity Center (SAML) ou certificados, baseando-se nos metadados fornecidos.
- Controles de monitoramento e conformidade, como logs no CloudWatch, GuardDuty, Inspector2 e baselines de patches via SSM.

## Pré-requisitos

1. **Terraform 1.5+** instalado localmente.
2. **Credenciais AWS** disponíveis via perfil nomeado (`AWS_PROFILE`) ou variáveis de ambiente padrão (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`). É necessário que o usuário certifique-se de que a identidade possui permissões para gerenciar redes VPC, EC2, IAM, ACM, Client VPN, CloudWatch, GuardDuty, Inspector e SSM.
3. **Certificados ACM** preparados antecipadamente:
   - `client_vpn_server_certificate_arn` para o endpoint do servidor VPN.
   - `client_vpn_root_certificate_arn` apenas se o usuário planeja usar autenticação baseada em certificados.
4. **Chave pública SSH** para instalação dos 'bastions' EC2.

## Configuração

1. O arquivo `terraform.tfvars` deve ser usado como modelo, substituindo todos os placeholders (`<...>`) pelos valores definidos pelo usuário.
2. No mínimo, devem ser preenchidas as seguintes variáveis:

```hcl
resource_prefix               = "my-team"
aws_region                    = "us-east-1"
aws_profile                   = "work-profile"      # optional
ssh_public_key               = file("~/.ssh/id_ed25519.pub")
client_vpn_server_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/..."
client_vpn_root_certificate_arn   = "arn:aws:acm-pca:us-east-1:123456789012:certificate/..." # required for certificate auth
client_vpn_saml_metadata_document = file("idp-metadata.xml") # leave empty for certificates
enable_expensive_resources    = false # true para habilitar NAT, EIP e Client VPN
```

3. A variável `client_vpn_saml_metadata_document` controla se a VPN será implantada com autenticação SAML ou por certificado. É necessário que sejam fornecidos metadados válidos do IAM Identity Center para habilitar o login federado; caso contrário, a stack implantará o endpoint com autenticação por certificado e vinculará o `client_vpn_root_certificate_arn`.
4. É necessário que se sobrescrevam os servidores DNS padrão, o bloco CIDR do cliente ou a chave SSH conforme necessário através das demais variáveis em `aws_variables.tf`.
5. A nova variável `enable_expensive_resources` mantém NAT/EIP e Client VPN desligados (valor padrão `false`). Deve ser ligada (`true`) apenas nos momentos de teste e usar `terraform destroy` quando terminar para evitar cobranças futuras.

## Implementação

1. Execute `terraform init` para baixar o provedor AWS.
2. (Opcional) `terraform validate` para verificar problemas de sintaxe ou configuração.
3. Verifique as mudanças planejadas:
   ```bash
   terraform plan -var-file=secrets.auto.tfvars
   ```
4. Aplique as mudanças:
   ```bash
   terraform apply -var-file=secrets.auto.tfvars
   ```

## Pós-Implantação

- Use `terraform output aws_client_vpn_endpoint` para obter o ID e o nome DNS do endpoint da VPN.
- Os IPs privados dos bastion hosts estão disponíveis via `terraform output aws_instance_private_ips`.
- Os IDs dos Security Groups são expostos através de `terraform output aws_security_groups` para auxiliar nas regras de firewall do cliente.
- O GuardDuty e o Inspector são ativados automaticamente; monitore seus consoles para alertas e resultados de varreduras.

## Limpeza

Quando o ambiente não for mais necessário, o seguinte comando deve ser executado:

```bash
terraform destroy -var-file=secrets.auto.tfvars
```

O decomissionamento deve usar o mesmo contexto de variáveis para que o Terraform localize os recursos criados.

---

## Segurança: 

Mantenha os ARNs dos certificados, o documento de metadados do IdP e o material da chave privada SSH em um cofre seguro (vault) ou gerenciador de segredos. Rotacione-os regularmente e reaplique a stack do Terraform sempre que as credenciais forem alteradas.
