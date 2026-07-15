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
      {
        // brandon-iphone
        target : ["100.76.234.121"],
        attr : ["mullvad"],
      },
      {
        // brandon-ipad-air
        target : ["100.64.153.110"],
        attr : ["mullvad"],
      },
      {
        // brandon-macbook-pro
        target : ["100.89.139.58"],
        attr : ["mullvad"],
      },
      {
        // qbittorrent
        target : ["100.84.136.31"],
        attr : ["mullvad"],
      },
    ],

    autoApprovers : {
      // tag:nixos covers the k3s nodes (tau-ceti, rocky) that advertise exit
      // nodes — they're now tagged, so approve by tag rather than user.
      "exitNode" : ["brandonwees@gmail.com", "tag:nixos"],
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


data "tailscale_device" "dns" {
  name     = "dns.${local.tailnet}"
  wait_for = "60s"
}

resource "tailscale_dns_split_nameservers" "bwees_lab" {
  domain      = "bwees.lab"
  nameservers = [data.tailscale_device.dns.addresses[0]]
}

resource "tailscale_dns_split_nameservers" "wees_home" {
  domain      = "wees.home"
  nameservers = [data.tailscale_device.dns.addresses[0]]
}
