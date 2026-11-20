{ config, ... }:

let
  # Matched by the MiroirNodeGroup of the same name: `std` (loopfile) or `thin` (lvmthin)
  storageClass = if config.homelab.disk.layout == "lvm" then "thin" else "std";
in
{
  boot.kernelModules = [
    "loop"
    "dm_thin_pool"
  ];

  services.k3s.extraFlags = [
    "--node-label=storage.miroir.home-operations.com/class=${storageClass}"
  ];
}
