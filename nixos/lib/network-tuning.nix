{
  ...
}:

# Sized for a gigabit flow at 75ms (~9.4MB in flight). Pods copy these when
# their network namespace is created, so restart them after a change.
{
  boot.kernelModules = [ "tcp_bbr" ];

  boot.kernel.sysctl = {
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.ipv4.tcp_rmem" = "4096 131072 33554432";
    "net.ipv4.tcp_wmem" = "4096 16384 33554432";
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
  };
}
