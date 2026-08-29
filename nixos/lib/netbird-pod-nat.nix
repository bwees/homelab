{
  ...
}:

let
  # Skips what FLANNEL-POSTRTG also skips: intra-cluster traffic, and packets carrying
  # kube-proxy's needs-SNAT mark (KUBE-POSTROUTING must still see those to clear it).
  rule = "-s 10.42.0.0/16 ! -d 10.42.0.0/16 -p udp -m mark ! --mark 0x4000/0x4000 -j MASQUERADE";
in
{
  # Lets a WireGuard client in a pod hole-punch like the hosts do, with no port forward.
  #
  # flannel masquerades pod egress with `--random-fully`, giving a fresh source port per
  # destination, so a peer's observed endpoint differs per STUN/relay server and it gives
  # up on a direct connection. Plain MASQUERADE keeps the source port, so the pod inherits
  # this router's endpoint-independent mapping.
  #
  # Goes at the head of POSTROUTING; flannel appends its jump, so a rule in front of it
  # survives flanneld's resync. Delete-then-insert because firewall reloads re-run this.
  networking.firewall.extraCommands = ''
    iptables -t nat -D POSTROUTING ${rule} 2>/dev/null || true
    iptables -t nat -I POSTROUTING 1 ${rule}
  '';

  networking.firewall.extraStopCommands = ''
    iptables -t nat -D POSTROUTING ${rule} 2>/dev/null || true
  '';
}
