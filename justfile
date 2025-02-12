set shell := ["zsh", "-c"]

_ansible_vault_op:
    op read "op://Homelab/2fgepkgmadwfgejymkitatma6u/password"

[working-directory: 'ansible']
deploy HOST:
    ansible-playbook playbooks/deploy.yml --vault-password-file <(just _ansible_vault_op) --limit {{HOST}}


[working-directory: 'ansible']
vault ACTION:
    EDITOR='code --wait' ansible-vault {{ACTION}} secrets.yml --vault-password-file <(just _ansible_vault_op)
