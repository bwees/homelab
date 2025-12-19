{
  modulesPath,
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
  ];
  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  services.openssh.enable = true;

  environment.systemPackages = map lib.lowPrio [
    pkgs.curl
    pkgs.gitMinimal
  ];

  # enable root login with SSH keys for initial setup
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDwIXvJQv6ZNrI9NvhvLlh5GewYWzIhK7krLw9oNzS5KzLO8IlxM4NEUsD4WK+PfuUBeyjjSNNbMnf9t1LqRPISLo7WS7qh9mw90Hm8P+GpuIpfuzxiacmkSYm1sHk+tPGki/t7hA3kCe2vSOQi1pbJlS4dzn51OWqWYPyptznhaSvq60Nfxer85RSvLLac0WTP2mi3X5YMYSK1EIc0mvudq/R6Gk7sc0hB1tvfpCHqN6dkpOOfwlStsALJ9jA3N6oz5S3+J6EuGj3sQoz3+K4xEW0bHWbTPJjgUZYGW+9b6vZOhWPUKoHBRKEQVnUq98LhJxWsu0waJH+ZwTHwD4QmTnArjyKQ29RxAy8KcNtbTdKmAtvI18VkqAPoFdZMKSWxqPMLrqXt4q3J8v2/OzSnZrwQ7A9BCxWRQM6vq910zWLjizIEvocR2JZ4d4S1ybZKmxgNtLL0SCSm7v7uJn4HquTlvIU339C0qWqtWFNfPI7MCsICnw89+PJwhxBkJhU="
  ];

  system.stateVersion = "23.11";
}
