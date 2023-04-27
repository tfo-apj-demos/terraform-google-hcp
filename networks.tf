resource "google_compute_network" "this" {
  name                    = local.naming_prefix
  auto_create_subnetworks = false
  routing_mode            = var.bgp_routing_mode
}

resource "google_compute_subnetwork" "this" {
  name          = local.naming_prefix
  ip_cidr_range = var.subnetwork_subnet == "" ? cidrsubnet(var.vpc_subnet, 5, 0) : var.subnetwork_subnet
  network       = google_compute_network.this.id
}


resource "google_compute_ha_vpn_gateway" "this" {
  name    = local.naming_prefix
  network = google_compute_network.this.id
}

resource "google_compute_router" "this" {
  name    = local.naming_prefix
  network = google_compute_network.this.name
  bgp {
    asn            = var.gcp_asn
    advertise_mode = "DEFAULT"
    #advertised_groups = ["ALL_SUBNETS"]
    # advertised_ip_ranges {
    #   range = "172.25.16.0/20"
    # }
  }
}


resource "aws_customer_gateway" "this" {
  count      = 2
  bgp_asn    = var.gcp_asn
  ip_address = google_compute_ha_vpn_gateway.this.vpn_interfaces[count.index].ip_address
  type       = "ipsec.1"

}

resource "aws_vpn_connection" "this" {
  count = 2
  #for_each = { for v in aws_customer_gateway.this: v.ip_address => v }
  transit_gateway_id  = "tgw-0f68a4f2c58772c51"
  type                = "ipsec.1"
  customer_gateway_id = aws_customer_gateway.this[count.index].id
}

resource "google_compute_external_vpn_gateway" "this" {
  name            = local.naming_prefix
  redundancy_type = "FOUR_IPS_REDUNDANCY"
  dynamic "interface" {
    for_each = flatten([for v in aws_vpn_connection.this : [v.tunnel1_address, v.tunnel2_address]])
    content {
      ip_address = interface.value
      id         = index(flatten([for v in aws_vpn_connection.this : [v.tunnel1_address, v.tunnel2_address]]), interface.value)
    }
  }
}

resource "google_compute_vpn_tunnel" "this" {
  count = length(google_compute_external_vpn_gateway.this.interface.*.id)
  name  = "${local.naming_prefix}-${count.index}"

  peer_external_gateway           = google_compute_external_vpn_gateway.this.id
  peer_external_gateway_interface = count.index

  shared_secret = local.pre_shared_keys[count.index]
  router        = google_compute_router.this.name

  vpn_gateway = google_compute_ha_vpn_gateway.this.name

  vpn_gateway_interface = floor(count.index / 2)

}

resource "google_compute_router_interface" "this" {
  count  = length(flatten([for v in aws_vpn_connection.this : [v.tunnel1_cgw_inside_address, v.tunnel2_cgw_inside_address]]))
  name   = "int-${count.index}"
  router = google_compute_router.this.name

  vpn_tunnel = google_compute_vpn_tunnel.this[count.index].id
  ip_range   = "${flatten([for v in aws_vpn_connection.this : [v.tunnel1_cgw_inside_address, v.tunnel2_cgw_inside_address]])[count.index]}/30"

}

resource "google_compute_router_peer" "this" {
  count                     = 4
  name                      = "${local.naming_prefix}-${count.index}"
  router                    = google_compute_router.this.name
  peer_ip_address           = flatten([for v in aws_vpn_connection.this : [v.tunnel1_vgw_inside_address, v.tunnel2_vgw_inside_address]])[count.index]
  peer_asn                  = "65001"
  advertised_route_priority = 100
  interface                 = "int-${count.index}"
}

# resource "google_compute_route" "default" {
#   name        = "network-route"
#   dest_range  = "172.25.16.0/20"
#   network     = google_compute_network.this.name

# 	next_hop_vpn_tunnel = google_compute_vpn_tunnel.this[0].id
#   priority    = 100
# }

# resource "aws_ec2_transit_gateway_route_table_propagation" "example" {
#   transit_gateway_attachment_id  = "tgw-0f68a4f2c58772c51"
#   transit_gateway_route_table_id = 
# }




locals {
  #aws_gateway_addresses = flatten([ for v in aws_vpn_connection.this: [ v.tunnel1_address, v.tunnel_address ]])
  pre_shared_keys = flatten([for v in aws_vpn_connection.this : [v.tunnel1_preshared_key, v.tunnel2_preshared_key]])
}

