{ ... }:

{
  boot.kernelModules = [
    "loop"
    "dm_thin_pool"
  ];

  # Matched by the `std` MiroirNodeGroup
  services.k3s.extraFlags = [
    "--node-label=storage.miroir.home-operations.com/class=std"
  ];
}
