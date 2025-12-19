

[working-directory: 'ansible']
deploy HOST="all:!homelab-router":
    ansible-playbook deploy.yml --limit {{ HOST }}

[working-directory: 'images']
build-custom-images:
    @docker buildx build --push --platform linux/amd64 \
        -f n8n-runner.Dockerfile \
        -t ghcr.io/bwees/homelab/n8n-runner:latest \
        -t ghcr.io/bwees/homelab/n8n-runner:`git rev-parse --short HEAD` .

[working-directory: 'nixos']
switch HOST USER="bwees":
    #!/bin/bash
    nixos-rebuild switch \
        --flake .#"{{HOST}}" \
        --target-host "{{USER}}@{{HOST}}" \
        --build-host "{{USER}}@{{HOST}}" \
        --use-remote-sudo \
        --fast

collection:
  ansible-galaxy collection install -r ansible/requirements.yml