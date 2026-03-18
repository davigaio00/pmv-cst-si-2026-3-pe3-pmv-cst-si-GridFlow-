variable "resource_prefix" {
  description = "Prefix applied to names and tags to keep the solution scoped to one project."
  type        = string
  default     = "zero-trust"
}

variable "enable_expensive_resources" {
  description = "FinOps toggle: habilita NAT, EIP e Client VPN apenas quando necessario."
  type        = bool
  default     = false
}

variable "aws_region" {
  description = "Primary AWS region where the zero trust infrastructure will be deployed."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Optional AWS CLI profile name to use when targeting the account."
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "Public SSH key material used to create a key pair for the Linux and Windows instances."
  type        = string
}

variable "client_vpn_server_certificate_arn" {
  description = "ARN of an ACM certificate that terminates the TLS handshake for the Client VPN endpoint. Create the certificate beforehand."
  type        = string
}

variable "client_vpn_root_certificate_arn" {
  description = "ARN of the private CA certificate chain that authorizes client-side certificates (only required when using certificate authentication)."
  type        = string
  default     = ""
}

variable "client_vpn_client_cidr" {
  description = "CIDR block assigned to clients when they connect to the Client VPN endpoint."
  type        = string
  default     = "10.0.255.0/27"
}

variable "client_vpn_saml_metadata_document" {
  description = "Optional SAML metadata document that represents IAM Identity Center or another IdP for VPN authentication. Leave empty to fall back to certificate authentication."
  type        = string
  default     = ""
}

variable "client_vpn_dns_servers" {
  description = "DNS servers pushed to the Client VPN clients."
  type        = list(string)
  default     = ["1.1.1.1", "1.0.0.1"]
}
