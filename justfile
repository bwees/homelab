
[private]
_resolve_secrets:
    @op inject -i "ansible/secrets.yml" -o "ansible/secrets.resolved.yml" -f

[private]
_cleanup_secrets:
    @rm -f ansible/secrets.resolved.yml

[working-directory: 'ansible']
deploy HOST="linode,home,nas,lab,stepien":
    @just _resolve_secrets

    ansible-playbook playbooks/deploy.yml --limit {{ HOST }}
    
    @just _cleanup_secrets

[working-directory: 'ansible']
tailscale-update HOST:
    ansible-playbook playbooks/tailscale-update.yml --limit {{ HOST }}

[working-directory: 'ansible']
dns HOST="linode,home":
    ansible-playbook playbooks/dns.yml --limit {{ HOST }}

[working-directory: 'ansible']
zfs-autosnap HOST:
    ansible-playbook playbooks/zfs-autosnap.yml --limit {{ HOST }}