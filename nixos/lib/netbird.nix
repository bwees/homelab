{
  pkgs,
  ...
}:

{
  config = {
    # The default client: interface wt0, WireGuard on :51820, firewall opened.
    # Nodes still log in by hand once - `netbird up --setup-key <key>` with the
    # cluster's key from `tofu output -json node_setup_keys` - because the key
    # carries the groups (nixos, <cluster>, and any exit-node group).
    services.netbird.enable = true;

    # Enables ip_forward and loose reverse-path filtering, needed to serve network
    # routes and exit nodes and to accept traffic arriving from them.
    services.netbird.useRoutingFeatures = "both";

    # fixes https://tailscale.com/s/ethtool-config-udp-gro - a userspace WireGuard
    # tunnel over a NIC with UDP GRO forwarding disabled loses most of its
    # throughput. NetBird's wireguard-go data path has the same problem.
    systemd.services.enable-udp-gro-forwarding = {
      description = "Enable UDP GRO forwarding for WireGuard tunnels";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig.Type = "oneshot";

      script = ''
        iface=$(${pkgs.iproute2}/bin/ip route show default | ${pkgs.gawk}/bin/awk '{print $5}' | head -n1)

        if [ -n "$iface" ]; then
          echo "Enabling UDP GRO forwarding on $iface"
          ${pkgs.ethtool}/bin/ethtool -K "$iface" rx-udp-gro-forwarding on
          ${pkgs.ethtool}/bin/ethtool -K "$iface" rx-gro-list off
        else
          echo "No default interface found"
          exit 1
        fi
      '';
    };
  };
}
