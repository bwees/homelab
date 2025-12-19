# Homelab

This repository houses the infrastructure configuration files (docker-compose) for my homelab as well as deployment playbooks (ansible). Configuration files for individual apps (ie container persistent storage) are not housed in this repository. All compute machines (excluding appliance devices like NAS and Homelab Router) run on a mix of NixOS/Ubuntu 24.04 and use Docker for application deployment.

## Hosts

- Lab (homelab-bwees)
  - This is my main homelab machine that self-hosts the majority of my applications.
- Home (homelab-home)
  - This machine stays at my parent's house and provides Home Assistant, Jellyfin, and a few other services.
- Linode (homelab-linode)
  - This is a Linode VPS (1 CPU, 1GB RAM) that provides mission critical services as well as being the entrypoint for all public traffic. Once public traffic hits homelab-linode, it is routed via Traefik to the destination host over Tailscale. This is similar to Cloudflare Tunnels and Pangolin based approaches.
- NAS (homelab-nas)
  - This is my main TrueNAS SCALE server. I use docker directly on the host rather than the Apps interface in TrueNAS. This is for consistency reasons so the deployment is the same as other hosts.
- Homelab Router (homelab-router)
  - This is a Unifi Express 7. Under the hood it runs debian and thus can be controlled quite easily with Ansible.

## Tailscale

Tailscale is used for all private networking. The Ansible host inventory uses Tailscale for all communication in playbooks.

I have 2 domains that are routed over Tailscale (using custom split DNS servers):

- `*.bwees.lab` - Personal Services
- `*.bwees.home` - Family Services

My personal domain is routed to my linode VPS which then uses Traefik and Tailscale to forward the connection to the correct server.

## Ansible

This year I decided to try and automate some of the tasks in my lab with Ansible. Ansible currently handles the following operations:

- Deployment of Docker-compose files and related secrets to each machine
- Secret Management
- Updating Tailscale
- DNS Configuration Deployment

### Secret Management

Secrets are stored in 1Password for security and CI/CD. Secrets are dumped via `op item get` as JSON, parsed, and rendered out to individual env files for each host.
