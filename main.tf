#GCP: VPC


#GCP: HA VPN GW and Cloud Router

# AWS: Customer gateways

# AWS: VPN with dynamic routing

# GCP: External VPN Gateway and tunnels


locals {
  naming_prefix  = "hcp"
  ssh_key_string = var.ssh_key_path != "" ? "${var.ssh_username}:${file(var.ssh_key_path)}" : null
}

data "google_compute_image" "this" {
  family  = var.server_compute_image_family
  project = var.server_compute_image_project != "" ? var.server_compute_image_project : null
}

resource "google_compute_instance" "this" {
  machine_type = var.machine_type
  name         = local.naming_prefix
  zone         = "${var.region}-a"
  boot_disk {
    initialize_params {
      image = data.google_compute_image.this.self_link
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.this.self_link
    access_config {
      // Ephemeral public IP
    }
  }
  metadata = {
    ssh-keys = local.ssh_key_string
  }
  tags = ["enable-ssh"]
}

resource "google_compute_firewall" "ssh" {
  count   = var.enable_ssh == true ? 1 : 0
  name    = "${local.naming_prefix}-ssh-access"
  network = google_compute_network.this.name

  source_ranges = var.my_public_ips

  allow {
    protocol = "tcp"
    ports = [
      22
    ]
  }
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
  target_tags = ["enable-ssh"]

  direction = "INGRESS"
}


# resource "aws_security_group" "gcp_to_hcp" {
# 	name = "gcp_to_hcp"

# }

# resource "aws_security_group_rule" "vault" {
# 	type = "ingress"
# 	cidr_blocks = [ var.vpc_subnet ]
# 	from_port = 8200
# 	to_port = 8200
# 	protocol = "TCP"
# 	security_group_id = aws_security_group.gcp_to_hcp.id
# }

resource "aws_network_acl" "this" {
  vpc_id = var.aws_vpc_id
}

resource "aws_network_acl_rule" "egress" {
  network_acl_id = aws_network_acl.this.id
  egress         = true
  protocol       = "tcp"
  rule_number    = 200
  rule_action    = "allow"
  cidr_block     = "172.25.16.0/20"
  from_port      = 8200
  to_port        = 8200
  # icmp_code = ""
  # icmp_type  = ""
  # ipv6_cidr_block = ""
}

resource "aws_network_acl_rule" "ingress" {
  network_acl_id = aws_network_acl.this.id
  egress         = false
  protocol       = "tcp"
  rule_number    = 100
  rule_action    = "allow"
  cidr_block     = var.vpc_subnet
  from_port      = 8200
  to_port        = 8200
  # icmp_code = ""
  # icmp_type  = ""
  # ipv6_cidr_block = ""
}

resource "google_compute_firewall" "icmp" {
  name               = "icmp"
  destination_ranges = ["172.25.16.0/20"]
  network            = google_compute_network.this.id
  #source_tags = ["enable-ssh"]
  allow {
    protocol = "icmp"
  }
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }

  direction = "EGRESS"
}


resource "google_compute_firewall" "vault_access" {
  name               = "hcp-vault-access"
  destination_ranges = ["172.25.16.0/20"]
  network            = google_compute_network.this.id
  #source_tags = ["enable-ssh"]
  allow {
    protocol = "tcp"
    ports = [
      8200
    ]
  }
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }

  direction = "EGRESS"
}