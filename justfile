
[private]
_resolve_secrets:
    @op inject -i "secrets.yml" -o "secrets.resolved.yml" -f

[private]
_cleanup_secrets:
    @rm -f secrets.resolved.yml

[working-directory: 'ansible']
deploy HOST="all:!homelab-router": _resolve_secrets &&  _cleanup_secrets
    exit 1
    ansible-playbook deploy.yml --limit {{ HOST }}

[working-directory: 'images']
build-custom-images:
    @docker buildx build --push --platform linux/amd64 \
        -f Dockerfile.n8n-runner \
        -t ghcr.io/bwees/homelab/n8n-runner:latest \
        -t ghcr.io/bwees/homelab/n8n-runner:`git rev-parse --short HEAD` .

[working-directory: 'nixos']
switch HOST USER="bwees":
    #!/bin/bash
    build_target=`jq -r '."{{HOST}}" // "{{HOST}}"' build-hosts.json`
    echo "Using build host: ${build_target}"
    nixos-rebuild switch \
        --flake .#"{{HOST}}" \
        --target-host "{{USER}}@{{HOST}}" \
        --build-host "{{USER}}@${build_target}" \
        --use-remote-sudo \
        --fast


collection:
  ansible-galaxy collection install -r ansible/requirements.yml