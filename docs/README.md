# AWS Zero Trust Deployment

> Este repositório está em formato de **template**. Antes de executar, preencha seus próprios valores no arquivo `terraform.tfvars`.

This workspace provisions a fully AWS-native zero trust perimeter that includes:

- A dedicated VPC with public and private subnets, NAT gateway, and hardened bastion hosts for Windows and Linux.
- Client VPN endpoints that switch between IAM Identity Center (SAML) and certificate authentication based on supplied metadata.
- Monitoring and compliance controls such as CloudWatch logging, GuardDuty, Inspector2, and SSM patch baselines.

## Prerequisites

1. **Terraform 1.5+** installed locally.
2. **AWS credentials** available either via a named profile (`AWS_PROFILE`) or the standard environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`). Ensure the principal has permissions to manage VPC networking, EC2, IAM, ACM, Client VPN, CloudWatch, GuardDuty, Inspector, and SSM.
3. **ACM certificates** prepared ahead of time:
   - `client_vpn_server_certificate_arn` for the VPN server endpoint.
   - `client_vpn_root_certificate_arn` only if you plan to use certificate-based authentication.
4. **SSH public key** material to install on the EC2 bastions.

## Configuration

1. Use o arquivo `terraform.tfvars` como modelo e substitua todos os placeholders (`<...>`) pelos seus valores.
2. No mínimo, preencha as seguintes variáveis:

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

3. The `client_vpn_saml_metadata_document` controls whether the VPN deploys with SAML or certificate authentication. Provide valid IAM Identity Center metadata to enable federated login; otherwise the stack deploys the certificate-authenticated endpoint and wires `client_vpn_root_certificate_arn`.
4. Override the default DNS servers, client CIDR block, or SSH key as needed via the remaining variables in `aws_variables.tf`.
5. A nova variável `enable_expensive_resources` mantém NAT/EIP e Client VPN desligados (valor padrão `false`). Ligue (`true`) só nos momentos de laboratório e rode `terraform destroy` quando terminar para evitar billing contínuo.

## Deployment

1. Run `terraform init` to download the AWS provider.
2. (Optional) `terraform validate` to catch syntax or configuration issues.
3. Inspect the planned changes:
   ```bash
   terraform plan -var-file=secrets.auto.tfvars
   ```
4. Apply the changes:
   ```bash
   terraform apply -var-file=secrets.auto.tfvars
   ```

## Post-Deployment

- Use `terraform output aws_client_vpn_endpoint` to get the VPN endpoint ID and DNS name.
- Bastion host private IPs are available via `terraform output aws_instance_private_ips`.
- Security group IDs are exposed through `terraform output aws_security_groups` to help with client firewall rules.
- GuardDuty and Inspector are enabled automatically; monitor their consoles for alerts and scan results.

## Cleanup

When you no longer need the environment, run:

```bash
terraform destroy -var-file=secrets.auto.tfvars
```

Destroy must use the same variable context so Terraform can find the resources it created.

---

Keep certificate ARNs, the IdP metadata document, and the SSH key private material in a secure vault or secrets manager. Rotate them regularly and reapply the Terraform stack when credentials change.
