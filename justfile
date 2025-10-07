
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
