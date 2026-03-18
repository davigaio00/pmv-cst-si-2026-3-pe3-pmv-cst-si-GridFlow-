locals {
  prefix             = var.resource_prefix
  default_tags       = {
    Project     = "AWS Zero Trust"
    ManagedBy   = "Terraform"
    Environment = "StudentLab"
  }
  windows_patch_group            = "${local.prefix}-patch-windows"
  linux_patch_group              = "${local.prefix}-patch-linux"
  expensive_resources_enabled    = var.enable_expensive_resources
  use_saml                       = length(trimspace(var.client_vpn_saml_metadata_document)) > 0
  vpn_dns_servers                = var.client_vpn_dns_servers
  windows_private_ip             = "10.0.1.4"
  linux_private_ip               = "10.0.2.4"
  
  # FinOps blindado com try()
  nat_gateway_id         = try(aws_nat_gateway.main[0].id, null)
  client_vpn_endpoint_id = try(aws_ec2_client_vpn_endpoint.saml[0].id, aws_ec2_client_vpn_endpoint.certificate[0].id, null)
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

resource "aws_vpc" "zero_trust" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.default_tags, { Name = "${local.prefix}-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.zero_trust.id

  tags = merge(local.default_tags, { Name = "${local.prefix}-igw" })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.zero_trust.id
  availability_zone       = data.aws_availability_zones.available.names[0]
  cidr_block              = "10.0.10.0/24"
  map_public_ip_on_launch = true

  tags = merge(local.default_tags, { Name = "${local.prefix}-public" })
}

resource "aws_subnet" "windows" {
  vpc_id            = aws_vpc.zero_trust.id
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = "10.0.1.0/24"

  tags = merge(local.default_tags, { Name = "${local.prefix}-subnet-windows" })
}

resource "aws_subnet" "linux" {
  vpc_id            = aws_vpc.zero_trust.id
  availability_zone = data.aws_availability_zones.available.names[1]
  cidr_block        = "10.0.2.0/24"

  tags = merge(local.default_tags, { Name = "${local.prefix}-subnet-linux" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.zero_trust.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(local.default_tags, { Name = "${local.prefix}-public-rt" })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  count = local.expensive_resources_enabled ? 1 : 0
  tags  = merge(local.default_tags, { Name = "${local.prefix}-nat-eip" })
  # FinOps: EIP só existe com o toggle ativo
}

resource "aws_nat_gateway" "main" {
  count         = local.expensive_resources_enabled ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public.id

  tags = merge(local.default_tags, { Name = "${local.prefix}-nat" })
  # FinOps: a NAT é provisionada somente para testes caros
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.zero_trust.id

  tags = merge(local.default_tags, { Name = "${local.prefix}-private-rt" })
}

resource "aws_route" "private_nat" {
  count                     = local.expensive_resources_enabled ? 1 : 0
  route_table_id            = aws_route_table.private.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id            = local.nat_gateway_id
  # FinOps: o tráfego privado só sai via NAT quando o toggle está on
}

resource "aws_route_table_association" "windows" {
  subnet_id      = aws_subnet.windows.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "linux" {
  subnet_id      = aws_subnet.linux.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "sg_windows" {
  name        = "${local.prefix}-sg-windows"
  description = "RDP dentro do tunel Client VPN"
  vpc_id      = aws_vpc.zero_trust.id

  ingress {
    description = "RDP via VPN"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.client_vpn_client_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.default_tags, { Name = "${local.prefix}-sg-windows" })
}

resource "aws_security_group" "sg_linux" {
  name        = "${local.prefix}-sg-linux"
  description = "SSH dentro do tunel Client VPN"
  vpc_id      = aws_vpc.zero_trust.id

  ingress {
    description = "SSH via VPN"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.client_vpn_client_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.default_tags, { Name = "${local.prefix}-sg-linux" })
}

resource "aws_security_group" "client_vpn" {
  name        = "${local.prefix}-sg-client-vpn"
  description = "Permite trafego do Client VPN"
  vpc_id      = aws_vpc.zero_trust.id

  ingress {
    description = "Client VPN pool"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.client_vpn_client_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.default_tags, { Name = "${local.prefix}-sg-client-vpn" })
}

data "aws_ami" "windows" {
  most_recent = true
  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
  owners = ["amazon"]
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}

resource "aws_key_pair" "student" {
  key_name   = "${local.prefix}-key"
  public_key = var.ssh_public_key
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_ssm" {
  name               = "${local.prefix}-ec2-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "inspector" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonInspector2ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${local.prefix}-ec2-profile"
  role = aws_iam_role.ec2_ssm.name
}

resource "aws_instance" "vm_win_01" {
  ami                         = data.aws_ami.windows.id
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.windows.id
  vpc_security_group_ids      = [aws_security_group.sg_windows.id]
  private_ip                  = local.windows_private_ip
  key_name                    = aws_key_pair.student.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2_ssm.name
  associate_public_ip_address = false

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  tags = merge(local.default_tags, {
    Name        = "EC2-W01"
    "Patch Group" = local.windows_patch_group
  })
}

resource "aws_instance" "vm_lin_01" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.linux.id
  vpc_security_group_ids      = [aws_security_group.sg_linux.id]
  private_ip                  = local.linux_private_ip
  key_name                    = aws_key_pair.student.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2_ssm.name
  associate_public_ip_address = false

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  tags = merge(local.default_tags, {
    Name        = "EC2-L01"
    "Patch Group" = local.linux_patch_group
  })
}

resource "aws_ssm_patch_baseline" "windows" {
  name             = "${local.prefix}-windows-baseline"
  operating_system = "WINDOWS"
  description      = "Baseline Windows Server 2022 com aprovacao automatica de patches criticos."

  approval_rule {
    approve_after_days = 7
    compliance_level    = "CRITICAL"

    patch_filter {
      key    = "CLASSIFICATION"
      values = ["CriticalUpdates", "SecurityUpdates"]
    }

    patch_filter {
      key    = "PRODUCT"
      values = ["WindowsServer2022"]
    }
  }

  tags = merge(local.default_tags, { Name = "${local.prefix}-baseline-windows" })
}

resource "aws_ssm_patch_group" "windows" {
  baseline_id = aws_ssm_patch_baseline.windows.id
  patch_group = local.windows_patch_group
}

resource "aws_ssm_patch_baseline" "linux" {
  name             = "${local.prefix}-linux-baseline"
  operating_system = "UBUNTU"
  description      = "Baseline Ubuntu 22.04 focado em seguranca."

  approval_rule {
    approve_after_days = 7
    compliance_level    = "CRITICAL"

    patch_filter {
      key    = "PRIORITY"
      values = ["Required", "Important"]
    }

    patch_filter {
      key    = "PRODUCT"
      values = ["Ubuntu22.04"]
    }
  }

  tags = merge(local.default_tags, { Name = "${local.prefix}-baseline-linux" })
}

resource "aws_ssm_patch_group" "linux" {
  baseline_id = aws_ssm_patch_baseline.linux.id
  patch_group = local.linux_patch_group
}

resource "aws_ssm_association" "windows_patch" {
  name                = "AWS-RunPatchBaseline"
  schedule_expression = "cron(0 3 ? * SUN *)"

  targets {
    key    = "tag:Patch Group"
    values = [local.windows_patch_group]
  }
  parameters = {
    Operation = "Install" # Adicione esta linha
  }
}

resource "aws_ssm_association" "linux_patch" {
  name                = "AWS-RunPatchBaseline"
  schedule_expression = "cron(0 4 ? * SUN *)"

  targets {
    key    = "tag:Patch Group"
    values = [local.linux_patch_group]
  }
  parameters = {
    Operation = "Install" # Adicione esta linha
  }
}

resource "aws_guardduty_detector" "this" {
  enable = true

  tags = merge(local.default_tags, { Name = "${local.prefix}-guardduty" })
}

resource "aws_inspector2_enabler" "account" {
  account_ids    = [data.aws_caller_identity.current.account_id]
  resource_types = ["EC2"]
}

resource "aws_cloudwatch_log_group" "client_vpn" {
  name              = "${local.prefix}-client-vpn"
  retention_in_days = 30

  tags = merge(local.default_tags, { Name = "${local.prefix}-client-vpn-log" })
}

resource "aws_cloudwatch_log_stream" "client_vpn" {
  name           = "${local.prefix}-client-vpn-stream"
  log_group_name = aws_cloudwatch_log_group.client_vpn.name
}

resource "aws_iam_saml_provider" "identity_center" {
  count                  = local.expensive_resources_enabled && local.use_saml ? 1 : 0
  name                   = "${local.prefix}-identity-center"
  saml_metadata_document = var.client_vpn_saml_metadata_document
  # FinOps: provider somente com VPN federada ativa
}

resource "aws_ec2_client_vpn_endpoint" "saml" {
  count                  = local.expensive_resources_enabled && local.use_saml ? 1 : 0
  description            = "Client VPN autenticado via IAM Identity Center"
  client_cidr_block      = var.client_vpn_client_cidr
  server_certificate_arn = var.client_vpn_server_certificate_arn
  transport_protocol     = "udp"
  split_tunnel           = false
  dns_servers            = local.vpn_dns_servers
  security_group_ids     = [aws_security_group.client_vpn.id]
  vpc_id                 = aws_vpc.zero_trust.id

  connection_log_options {
    enabled               = true
    cloudwatch_log_group  = aws_cloudwatch_log_group.client_vpn.name
    cloudwatch_log_stream = aws_cloudwatch_log_stream.client_vpn.name
  }

  authentication_options {
    type = "federated-authentication"

    saml_provider_arn = aws_iam_saml_provider.identity_center[0].arn
  }

  tags = merge(local.default_tags, { Name = "${local.prefix}-client-vpn" })
}

resource "aws_ec2_client_vpn_endpoint" "certificate" {
  count                  = local.expensive_resources_enabled && !local.use_saml ? 1 : 0
  description            = "Client VPN autenticado via certificados"
  client_cidr_block      = var.client_vpn_client_cidr
  server_certificate_arn = var.client_vpn_server_certificate_arn
  transport_protocol     = "udp"
  split_tunnel           = false
  dns_servers            = local.vpn_dns_servers
  security_group_ids     = [aws_security_group.client_vpn.id]
  vpc_id                 = aws_vpc.zero_trust.id

  connection_log_options {
    enabled               = true
    cloudwatch_log_group  = aws_cloudwatch_log_group.client_vpn.name
    cloudwatch_log_stream = aws_cloudwatch_log_stream.client_vpn.name
  }

  authentication_options {
    type                     = "certificate-authentication"
    root_certificate_chain_arn = var.client_vpn_root_certificate_arn
  }

  tags = merge(local.default_tags, { Name = "${local.prefix}-client-vpn" })
}

resource "aws_ec2_client_vpn_network_association" "windows" {
  count                  = local.expensive_resources_enabled ? 1 : 0
  client_vpn_endpoint_id = local.client_vpn_endpoint_id
  subnet_id              = aws_subnet.windows.id
}

resource "aws_ec2_client_vpn_network_association" "linux" {
  count                  = local.expensive_resources_enabled ? 1 : 0
  client_vpn_endpoint_id = local.client_vpn_endpoint_id
  subnet_id              = aws_subnet.linux.id
}

resource "aws_ec2_client_vpn_authorization_rule" "vpc_access" {
  count                  = local.expensive_resources_enabled ? 1 : 0
  client_vpn_endpoint_id = local.client_vpn_endpoint_id
  target_network_cidr    = aws_vpc.zero_trust.cidr_block
  authorize_all_groups   = true
}

output "aws_client_vpn_endpoint_id" {
  description = "Client VPN endpoint ID."
  value       = local.client_vpn_endpoint_id
}

output "aws_instance_private_ips" {
  description = "Private IPs for the bastion hosts."
  value = {
    windows = aws_instance.vm_win_01.private_ip
    linux   = aws_instance.vm_lin_01.private_ip
  }
}

output "aws_security_groups" {
  value = {
    windows = aws_security_group.sg_windows.id
    linux   = aws_security_group.sg_linux.id
  }
}

output "aws_guardduty_detector_id" {
  value       = aws_guardduty_detector.this.id
  description = "GuardDuty detector ID"
}

output "aws_inspector2_account" {
  value       = aws_inspector2_enabler.account.account_ids
  description = "Inspector2 enabler target account"
}
