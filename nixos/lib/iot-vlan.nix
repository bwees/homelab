{ config, lib, ... }:

let
  cfg = config.homelab.iotVlan;
in
{
  options.homelab.iotVlan.parent = lib.mkOption {
    type = lib.types.str;
    description = "NIC whose switch port carries the tagged IoT VLAN.";
  };

  config = {
    # Pods attach to this link with macvlan. The node itself takes no address,
    # so it stays off the IoT network and needs no firewall rules for it.
    networking.networkmanager.ensureProfiles.profiles.iot0 = {
      connection = {
        id = "iot0";
        type = "vlan";
        interface-name = "iot0";
      };
      vlan = {
        parent = cfg.parent;
        id = "30";
      };
      ipv4.method = "disabled";
      ipv6.method = "disabled";
    };

    services.k3s.extraFlags = [ "--node-label=lab.bwees/iot-vlan=true" ];
  };
}
