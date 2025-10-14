
[private]
_resolve_secrets:
    @op inject -i "ansible/secrets.yml" -o "ansible/secrets.resolved.yml" -f

[private]
_cleanup_secrets:
    @rm -f ansible/secrets.resolved.yml

[working-directory: 'ansible']
deploy HOST="all:!homelab-router":
    @just _resolve_secrets

    ansible-playbook playbooks/deploy.yml --limit {{ HOST }}
    
    @just _cleanup_secrets

[working-directory: 'images']
build-custom-images:
    @docker buildx build --push --platform linux/amd64 -f Dockerfile.n8n-runner -t ghcr.io/bwees/homelab/n8n-runner:latest -t ghcr.io/bwees/homelab/n8n-runner:{{ git rev-parse --short HEAD }} .
