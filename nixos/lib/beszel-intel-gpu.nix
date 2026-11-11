{ lib, pkgs, ... }:

{
  services.beszel.agent.extraPath = [ pkgs.intel-gpu-tools ];

  # intel_gpu_top reads the i915 PMU through perf_event_open, which needs CAP_PERFMON in the host user namespace
  systemd.services.beszel-agent.serviceConfig = {
    AmbientCapabilities = [ "CAP_PERFMON" ];
    CapabilityBoundingSet = [ "CAP_PERFMON" ];
    PrivateUsers = lib.mkForce false;
    SystemCallFilter = [ "perf_event_open" ];
  };
}
