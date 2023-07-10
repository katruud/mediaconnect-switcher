variable "vpc_id" {
  type        = string
  description = "The ID of the media VPC"
}

variable "public_subnet_cidr" {
  type        = string
  description = "The CIDR block for the subnet"
}

variable "thumbprint" {
  type        = string
  description = "OIDC"
}

variable "github_repo" {
  type        = string
  description = "OIDC Github Repo"
}

variable "subdomain" {
  type        = string
  description = "Subdomain"
}

variable "domain" {
  type        = string
  description = "Domain"
}