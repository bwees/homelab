# NixOS Anywhere

Based on https://github.com/edouardparis/nixos-ovh-vps-example

## Install Steps

1. Add ssh key to root user in `/root/.ssh/authorized_keys`
2. `sh <(curl -L https://nixos.org/nix/install) --daemon`
   - Log out and back in to have nix available in your shell
3. Generate a hardware config

   ```bash
   nix-env -iE "_: with import <nixpkgs/nixos> { configuration = {}; }; \
    with config.system.build; [ nixos-generate-config ]"

   nixos-generate-config --show-hardware-config --no-filesystems
   ```

4. Copy the generated hardware config to `nixos/anywhere/hardware-configuration.nix`

5. Verify the disk device names in `nixos/anywhere/disk-config.nix` are correct using `lsblk` on the target machine.

6. `nix run github:nix-community/nixos-anywhere -- --flake .#machine root@<machine-ip>`

7. When creating the initial nixos config, use the local IP address of the machine as its name.

8. `just switch <machine-ip> root`
