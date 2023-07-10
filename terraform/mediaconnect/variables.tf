variable "vpc_cidr" {
  type        = string
  description = "CIDR range of VPC"
}

variable "private_subnet_cidr" {
  type        = string
  description = "Private Subnet CIDR values"
}

variable "mediaconnect_role" {
  type        = string
  description = "Mediaconnect role ID"
}

variable "vpc_peer" {
  type        = string
  description = "VPC Peer ID"
}

variable "hub_subnet_cidr" {
  type        = string
  description = "Hub Subnet CIDR values"
}

variable "spoke_region" {
  type        = string
  description = "Is this a spoke region?"
}

variable "flows" {
  description = "Individual flows to create"
}