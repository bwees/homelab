resource "tailscale_acl" "acls" {
  acl = jsonencode({
    tagOwners : merge(
      {
        "tag:ci" : [var.admin],

        // platform tags
        "tag:nixos" : [var.admin],
        "tag:kube-operator" : [var.admin, "tag:kube-operator"],
        "tag:kube-service" : [var.admin, "tag:kube-operator"],
      },
      // cluster tags
      { for cluster in var.clusters : "tag:${cluster}" => [var.admin, "tag:kube-operator"] },
    ),

    acls : [
      {
        action : "accept",
        src : ["*"],
        dst : ["*:*"],
      },
    ],

    grants : [
      {
        // tau-ceti's gatus sidecars read every cluster's routes through the operator API proxy
        src : ["tag:tau-ceti"],
        dst : ["tag:kube-operator"],
        app : {
          "tailscale.com/cap/kubernetes" : [
            { impersonate : { groups : ["gatus-reader"] } },
          ],
        },
      },
    ],

    nodeAttrs : [
      for mullvad_device in data.tailscale_device.mullvad_nodes : {
        target : [mullvad_device.addresses[0]],
        attr : ["mullvad"],
      }
    ],

    autoApprovers : {
      "exitNode" : ["tag:nixos", var.admin],
      "services" : {
        for cluster in var.clusters : "svc:${cluster}-ingress" => ["tag:kube-service"]
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
  for_each = var.mullvad_nodes

  name     = "${each.value}.${var.tailnet}"
  wait_for = "60s"
}

resource "tailscale_oauth_client" "operator" {
  description = "kubernetes operator"
  scopes      = ["devices:core", "auth_keys", "services"]
  tags        = ["tag:kube-operator"]
}

resource "onepassword_item" "operator" {
  vault    = var.vault_uuid
  title    = "tailscale-operator"
  category = "password"

  section_map = {
    "credentials" = {
      field_map = {
        "client_id" = {
          type  = "STRING"
          value = tailscale_oauth_client.operator.id
        }
        "client_secret" = {
          type  = "CONCEALED"
          value = tailscale_oauth_client.operator.key
        }
      }
    }
  }
}
