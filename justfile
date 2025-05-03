set shell := ["zsh", "-c"]

[private]
_ansible_vault_op:
    @op read "op://Homelab/2fgepkgmadwfgejymkitatma6u/password"

[working-directory: 'ansible']
deploy HOST="linode,home,nas,lab":
    ansible-playbook playbooks/deploy.yml --vault-password-file <(just _ansible_vault_op) --limit {{ HOST }}

[working-directory: 'ansible']
tailscale-update HOST:
    ansible-playbook playbooks/tailscale-update.yml --limit {{ HOST }}

[working-directory: 'ansible']
vault ACTION:
    EDITOR='code --wait' ansible-vault {{ ACTION }} secrets.yml --vault-password-file <(just _ansible_vault_op)

[working-directory: 'ansible']
beszel ACTION HOST="linode,home,lab,router":
    if [ "{{ ACTION }}" = "install" ]; then \
        ansible-playbook playbooks/install-beszel.yml --vault-password-file <(just _ansible_vault_op) --limit {{ HOST }}; \
    elif [ "{{ ACTION }}" = "update" ]; then \
        ansible-playbook playbooks/update-beszel.yml --limit {{ HOST }}; \
    else \
        echo "Invalid action. Use 'install' or 'update'."; \
    fi

[working-directory: 'ansible']
dns HOST="linode,home":
    ansible-playbook playbooks/dns.yml --limit {{ HOST }}

[working-directory: 'ansible']
zfs-autosnap HOST:
    ansible-playbook playbooks/zfs-autosnap.yml --limit {{ HOST }}