

[working-directory: 'deploy/ansible']
deploy HOST="all:!homelab-router":
    ansible-playbook deploy.yml --limit {{ HOST }}

[group: "images"]
mod images "images"

[working-directory: 'nixos']
switch HOST USER="bwees":
  nixos-rebuild switch \
    --flake .#"{{HOST}}" \
    --target-host "{{USER}}@{{HOST}}" \
    --build-host "{{USER}}@{{HOST}}" \
    --sudo \
    --no-reexec

[working-directory: 'nixos']
anywhere HOST IP USER="root":
  nix run github:nix-community/nixos-anywhere -- --flake .#"{{HOST}}" "{{USER}}@{{IP}}"

[working-directory: 'deploy/ansible']
collection:
  ansible-galaxy collection install -r requirements.yml

[working-directory: 'restic']
restic CREDS REPO *ARGS:
  #!/bin/bash
  set -a
  source ./credentials/restic.{{CREDS}}.env
  RESTIC_REPOSITORY="${RESTIC_REPOSITORY}/{{REPO}}" \
  restic {{ARGS}}

bootstrap HOST USER="bwees":
  #!/bin/bash
  set -euo pipefail

  # Ensure the external-secrets namespace exists
  ssh "{{USER}}@{{HOST}}" 'sudo k3s kubectl create namespace external-secrets \
    --dry-run=client -o yaml | sudo k3s kubectl apply -f -'

  # 1Password service-account token -> external-secrets secret on the host
  op read --no-newline "op://Homelab Deployment/1password-service-account/credential" \
    | ssh "{{USER}}@{{HOST}}" 'sudo k3s kubectl create secret generic onepassword-secret-token \
        --namespace external-secrets \
        --from-file=token=/dev/stdin \
        --dry-run=client -o yaml | sudo k3s kubectl apply -f -'

  # Shared k3s cluster token -> /etc/rancher/k3s/cluster-token on the host
  # op read "op://Homelab Deployment/hail-mary-k3s/cluster-token" \
  #   | ssh "{{USER}}@{{HOST}}" 'sudo mkdir -p /etc/rancher/k3s && sudo tee /etc/rancher/k3s/cluster-token >/dev/null'
