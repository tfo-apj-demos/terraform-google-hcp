# Provider variables
variable "project" {
  default = "go-gcp-demos"
}

variable "region" {
  default = "australia-southeast1"
}

# Network variables
variable "vpc_subnet" {
  default = "172.16.0.0/16"
}

variable "gcp_network_name" {
  default = "hcp"
}

variable "bgp_routing_mode" {
  default = "GLOBAL"
}

variable "subnetwork_subnet" {
  default = ""
}

variable "aws_vpc_id" {
  type = string
}

variable "gcp_asn" {
  default = 64614
}

variable "machine_type" {
  default = "e2-medium"
}

variable "server_compute_image_project" {
  default = ""
}

variable "server_compute_image_family" {
  default = "nomad"
}

variable "ssh_key_path" {
  default = "~/.ssh/id_rsa.pub"
}

variable "ssh_username" {
  default = "ubuntu"
}

variable "my_public_ips" {
  default = []
}

variable "enable_ssh" {
  default = false
}

# 