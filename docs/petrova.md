# petrova

UniFi Express 7 router (UniFi OS 5.x, `ssh root@petrova`). Runs Tailscale as the subnet router
for the home VLANs and as an exit node.

| VLAN | Subnet            |
| ---- | ----------------- |
| 10   | `192.168.10.0/24` |
| 30   | `192.168.30.0/24` |
| 50   | `192.168.50.0/24` |

## Install Tailscale

Tailscale is installed with [tailscale-udm](https://github.com/SierraSoftworks/tailscale-udm).
It keeps its files in `/data/tailscale` and symlinks `tailscale-install.service`/`.timer` into
`/etc/systemd/system`, which reinstalls the package after a firmware update.

```bash
curl -sSLq https://raw.github.com/SierraSoftworks/tailscale-udm/main/install.sh | sh
```

Bring it up advertising the VLANs and the exit node:

```bash
tailscale up \
  --advertise-routes=192.168.10.0/24,192.168.30.0/24,192.168.50.0/24 \
  --advertise-exit-node
```

Approve the routes and exit node in the Tailscale admin console.

`/etc/default/tailscaled` is rewritten from `/data/tailscale/tailscale-env` on every
`manage.sh on-boot`. Only `PORT` and `TAILSCALED_FLAGS` carry over. Set other daemon
settings with the drop-in below, not in that file.

## Disable TCP GRO

Required. With GRO on, tailscaled merges forwarded TCP segments into 2400–3600 byte packets.
UniFi's hardware forwarding path drops them before they reach the LAN, and subnet-routed TCP
falls to ~45 KB/s. With GRO off it runs at ~7 MB/s.

The drop-in lives on `/data` and is symlinked into `/etc`, the same way tailscale-udm
persists its units:

```bash
mkdir -p /data/tailscale-overrides /etc/systemd/system/tailscaled.service.d
printf '[Service]\nEnvironment=TS_TUN_DISABLE_TCP_GRO=true\n' \
  > /data/tailscale-overrides/10-disable-tcp-gro.conf
ln -sf /data/tailscale-overrides/10-disable-tcp-gro.conf \
  /etc/systemd/system/tailscaled.service.d/10-disable-tcp-gro.conf
systemctl daemon-reload
systemctl restart tailscaled
```

Restarting tailscaled drops subnet routes for a few seconds. Run it from the LAN, or detach it
with `setsid`, if your SSH session goes over Tailscale.

## Verify

```bash
# on petrova: should print TS_TUN_DISABLE_TCP_GRO=true
tr '\0' '\n' < /proc/$(pidof tailscaled)/environ | grep GRO

# from a tailnet client routed through petrova: expect MB/s, not KB/s
dd if=/dev/zero bs=1M count=50 | ssh bwees@192.168.50.110 'cat >/dev/null'
```

Check both after every firmware update.
