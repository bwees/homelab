{
  ...
}:

{

  # Sanoid for ZFS snapshot management
  services.sanoid = {
    enable = true;
    datasets = {
      "main/personal" = {
        autosnap = true;
        autoprune = true;

        daily = 7;
        monthly = 4;
      };
    };
  };
}
