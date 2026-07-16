{ ... }:

# AMD GPU node for Wolf/Fenrir game sessions. Exposes /dev/dri (render) and
# /dev/kfd (ROCm compute) so the generic-device-plugin can advertise them as
# squat.ai/dri. Import this alongside k3s-multinode.nix on the GPU node and set
# the node label (see nixos/hosts/README or the fenrir app README):
#
#   services.k3s.extraFlags = [ "--node-label=lab.bwees/role=gpu" ];
#
# Do NOT add a node-taint: Fenrir session pods cannot express a toleration, so a
# taint makes them unschedulable. The squat.ai/dri resource alone pins them here.
{
  boot.initrd.kernelModules = [ "amdgpu" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
