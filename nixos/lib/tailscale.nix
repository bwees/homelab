{
  pkgs,
  ...
}:

{
  config = {
    services.tailscale.enable = true;
    services.tailscale.useRoutingFeatures = "server";

    # fixes https://tailscale.com/s/ethtool-config-udp-gro
    systemd.services.enable-udp-gro-forwarding = {
      description = "Enable UDP GRO forwarding for Tailscale";
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
