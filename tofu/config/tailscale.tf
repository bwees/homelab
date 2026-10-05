locals {
  mullvad_nodes = [
    "brandon-iphone-17",
    "brandon-ipad-air",
    "brandon-macbook-pro",
    "qbittorrent"
  ]
}

resource "tailscale_acl" "acls" {
  acl = jsonencode({
    tagOwners : {
      "tag:ci" : ["brandonwees@gmail.com"],

      // cluster tags
      "tag:tau-ceti" : ["brandonwees@gmail.com", "tag:kube-operator"],
      "tag:hail-mary" : ["brandonwees@gmail.com", "tag:kube-operator"],
      "tag:stepien" : ["brandonwees@gmail.com", "tag:kube-operator"],
      "tag:eridani" : ["brandonwees@gmail.com", "tag:kube-operator"],

      // platform tags
      "tag:nixos" : ["brandonwees@gmail.com"],
      "tag:kube-operator" : ["brandonwees@gmail.com", "tag:kube-operator"],
      "tag:kube-service" : ["brandonwees@gmail.com", "tag:kube-operator"],
    },

    acls : [
      {
        action : "accept",
        src : ["*"],
        dst : ["*:*"],
      },
    ],

    nodeAttrs : [
      for mullvad_device in data.tailscale_device.mullvad_nodes : {
        target : [mullvad_device.addresses[0]],
        attr : ["mullvad"],
      }
    ],

    autoApprovers : {
      "exitNode" : ["tag:nixos", "brandonwees@gmail.com"],
      "services" : {
        for cluster in local.clusters : "svc:${cluster}-ingress" => ["tag:kube-service"]
      },
    },
  })

  overwrite_existing_content = true
}

resource "tailscale_dns_preferences" "preferences" {
  magic_dns = true
}

resource "tailscale_dns_nameservers" "nameservers" {
  nameservers = [
    "1.1.1.1",
    "1.0.0.1",
    "2606:4700:4700::1111",
    "2606:4700:4700::1001"
  ]
}

resource "tailscale_dns_search_paths" "search_paths" {
  search_paths = [
    "taila68cb8.ts.net",
    "tail5f8a8.ts.net"
  ]
}

data "tailscale_device" "mullvad_nodes" {
  for_each = toset(local.mullvad_nodes)

  name     = "${each.value}.${local.tailnet}"
  wait_for = "60s"
}

resource "tailscale_oauth_client" "kube_operator" {
  description = "kubernetes operator"
  scopes      = ["devices:core", "auth_keys", "services"]
  tags        = ["tag:kube-operator"]
}

resource "onepassword_item" "tailscale_kube_operator" {
  vault    = data.onepassword_vault.homelab_deployment.uuid
  title    = "tailscale-operator"
  category = "password"

  section_map = {
    "credentials" = {
      field_map = {
        "client_id" = {
          type  = "STRING"
          value = tailscale_oauth_client.kube_operator.id
        }
        "client_secret" = {
          type  = "CONCEALED"
          value = tailscale_oauth_client.kube_operator.key
        }
      }
    }
  }
}

import {
  to = onepassword_item.tailscale_kube_operator
  id = "vaults/7bnwnvda73bz3n634nb5bzoz3y/items/pidamurwg6gq7sjs55si6myqia"
}
