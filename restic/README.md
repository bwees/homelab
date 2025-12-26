# Restic

Restic is used for all remote backups. Secrets are stored in 1Password and injected to
create .env files for use on the hosts.

## Configure host for restic backups

```bash
    just copy-restic-creds HOSTNAME
```
