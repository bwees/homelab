# New Host Template

`lib/common.nix` is added to every host by `mkHost`, so a new host only needs its hostname, timezone, disk and hardware config.

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

4. Copy `base/` for the new host and add it to `nixosConfigurations` in `flake.nix`

5. Copy the generated hardware config to `hardware-configuration.nix`

6. Set `homelab.disk.device` to the install disk, checked with `lsblk` on the target machine.

7. `mise run nixos:anywhere <hostname> <machine-ip>`
