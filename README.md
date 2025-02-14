# Homelab

This repository houses the infrastructure configuration files (docker-compose) for my homelab as well as deployment playbooks (ansible). Configuration files for individual apps (ie container persistent storage) are not housed in this repository. All machines run on Ubuntu 24.04 and use Docker for application deployment.

## Hosts
- Lab (homelab-bwees)
  - This is my main homelab machine that self-hosts the majority of my applications.
- Home (homelab-home)
  - This machine stays at my parent's house and provides Home Assistant, Jellyfin, and a few other services.
- Linode (homelab-linode)
  - This is a Linode VPS (1 CPU, 1GB RAM) that provides a Tailscale Exit Node for the media stack and hosts some mission critical services.
 
## Tailscale
Tailscale is used for all private networking. I have 2 domains that are routed over Tailscale (using custom split DNS servers): 
  - `*.bwees.lab` - Personal Services
  - `*.bwees.home` - Family Services

## Cloudflare Tunnels
Cloudflare tunnels is used to route any services that need to be publicly accessible on my domain. This simplifies a lot of firewall configuration and is rarely used since most traffic is routed through Tailscale.

## Ansible
This year I decided to try and automate some of the tasks in my lab with Ansible. Ansible currently handles the following operations:
- Deployment of Docker-compose files and related secrets to each machine
- Secret Management

### Secret Management
Secrets are saved in a Ansible Vault inside of `ansible/secrets.yml` (not commited for security reasons). The vault is unlocked by Ansible with the 1Password CLI tool. `justfile` provides the necessary functions to retrieve the password for the Ansible deployment and vault commands.
