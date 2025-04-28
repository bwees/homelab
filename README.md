# Homelab

This repository houses the infrastructure configuration files (docker-compose) for my homelab as well as deployment playbooks (ansible). Configuration files for individual apps (ie container persistent storage) are not housed in this repository. All compute machines (excluding appliance devices like NAS and Homelab Router) run on Ubuntu 24.04 and use Docker for application deployment.

## Hosts
- Lab (homelab-bwees)
  - This is my main homelab machine that self-hosts the majority of my applications.
- Home (homelab-home)
  - This machine stays at my parent's house and provides Home Assistant, Jellyfin, and a few other services.
- Linode (homelab-linode)
  - This is a Linode VPS (1 CPU, 1GB RAM) that provides a Tailscale Exit Node for the media stack and hosts some mission critical services.
- NAS (bwees-nas)
  - This is my main TrueNAS SCALE server. This repo manages the docker containers that run via SCALE's app system.
  - Credentials are handled via Jinja2 templating instead of env variables since SCALE does not support docker-compose deployment.
- Homelab Router (homelab-router)
  - This is a Unifi Express 7. Under the hood it runs debian and thus can be controlled quite easily with Ansible.
 
## Tailscale
Tailscale is used for all private networking. The Ansible host inventory uses Tailscale for all communication in playbooks.

I have 2 domains that are routed over Tailscale (using custom split DNS servers): 
  - `*.bwees.lab` - Personal Services
  - `*.bwees.home` - Family Services

These internal domains' DNS are served by 2 Bind DNS servers. One on `homelab-linode`, and one on `homelab-home`. They are configured in `configs/dns/<host>` and dynamically updated with `just dns`


## Cloudflare Tunnels
Cloudflare tunnels is used to route any services that need to be publicly accessible on my domain. This simplifies a lot of firewall configuration and is rarely used since most traffic is routed through Tailscale.

## Ansible
This year I decided to try and automate some of the tasks in my lab with Ansible. Ansible currently handles the following operations:
- Deployment of Docker-compose files and related secrets to each machine
- Secret Management
- Installation of Beszel Agent
- Updating Tailscale
- DNS Configuration Deployment

### Secret Management
Secrets are saved in a Ansible Vault inside of `ansible/secrets.yml` (not commited for security reasons). The vault is unlocked by Ansible with the 1Password CLI tool. `justfile` provides the necessary functions to retrieve the password for the Ansible deployment and vault commands.
