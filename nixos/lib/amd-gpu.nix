{ ... }:

# AMD GPU support for Wolf game-streaming on xenonite. Loads amdgpu early and
# enables the mesa userspace so /dev/dri (renderD128) is usable. Wolf itself
# accesses the GPU via a hostPath /dev mount; the app containers it launches on
# dockerd get /dev/dri passed through by Wolf.
{
  boot.initrd.kernelModules = [ "amdgpu" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
