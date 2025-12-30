{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.restic;

  # Create a systemd service for copying from one restic repo to another
  mkCopyService =
    backupName: copyName: copyConfig:
    let
      sourceBackup = cfg.backups.${backupName};
    in
    {
      name = "restic-copies-${backupName}-to-${copyName}";
      value = {
        description = "Restic copy from ${backupName} to ${copyName}";
        path = with pkgs; [ restic ];

        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };

        script = ''
          set -Eeuoa pipefail

          # Source the source repository credentials
          ${optionalString (sourceBackup.environmentFile != null) ''
            source ${sourceBackup.environmentFile}
          ''}

          export RESTIC_FROM_REPOSITORY=$RESTIC_REPOSITORY
          export RESTIC_FROM_PASSWORD=$RESTIC_PASSWORD

          echo "Copying snapshots from ${backupName} to ${copyName}..."

          # Source the destination repository credentials
          ${optionalString (copyConfig.environmentFile != null) ''
            source ${copyConfig.environmentFile}
          ''}

          # Set explicit repository if provided
          ${optionalString (copyConfig.repository != null && copyConfig.repository != "") ''
            export RESTIC_REPOSITORY="${copyConfig.repository}"
          ''}

          # Set password from file if provided
          ${optionalString (copyConfig.passwordFile != null) ''
            export RESTIC_PASSWORD_FILE=${copyConfig.passwordFile}
          ''}

          # Run the copy command
          restic copy ${concatStringsSep " " copyConfig.extraCopyArgs}

          ${optionalString (copyConfig.prune.enable) ''
            echo "Pruning old snapshots on ${copyName}..."
            restic forget --prune ${concatStringsSep " " copyConfig.prune.pruneOpts}
          ''}

          echo "Copy ${backupName} restic repository to ${copyName} completed successfully"
        '';
      };
    };

  # Collect all copy services for all backups
  allCopyServices = flatten (
    mapAttrsToList (
      backupName: backupConfig:
      mapAttrsToList (copyName: copyConfig: mkCopyService backupName copyName copyConfig) (
        backupConfig.copies or { }
      )
    ) cfg.backups
  );

  # Get copy service names for a specific backup
  backupCopyServices =
    backupName:
    mapAttrsToList (copyName: copyConfig: "restic-copies-${backupName}-to-${copyName}.service") (
      cfg.backups.${backupName}.copies or { }
    );
in
{
  # Extend the existing restic.backups.<name> submodule to add copies option
  options.services.restic.backups = mkOption {
    type = types.attrsOf (
      types.submodule (
        { config, ... }:
        {
          options.copies = mkOption {
            type = types.attrsOf (
              types.submodule {
                options = {
                  repository = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Destination repository URL";
                  };

                  environmentFile = mkOption {
                    type = types.nullOr types.path;
                    default = null;
                    description = "Environment file containing credentials for destination repository";
                  };

                  passwordFile = mkOption {
                    type = types.nullOr types.path;
                    default = null;
                    description = "Password file for destination repository";
                  };

                  extraCopyArgs = mkOption {
                    type = types.listOf types.str;
                    default = [ ];
                    description = "Extra arguments to pass to restic copy command";
                    example = [ "--host myhost" ];
                  };

                  prune = {
                    enable = mkOption {
                      type = types.bool;
                      default = true;
                      description = "Whether to prune old snapshots after copying";
                    };

                    pruneOpts = mkOption {
                      type = types.listOf types.str;
                      default = config.pruneOpts;
                      description = "Options to pass to restic forget when pruning";
                    };
                  };
                };
              }
            );
            default = { };
            description = "Restic repository copies to run after this backup completes";
          };
        }
      )
    );
  };

  config =
    let
      hasAnyCopies = any (backup: (backup.copies or { }) != { }) (attrValues cfg.backups);
    in
    mkIf hasAnyCopies {
      # Create systemd services for each copy and add OnSuccess hooks to source backups
      systemd.services =
        # Create copy services
        listToAttrs allCopyServices
        # Add OnSuccess to backup services
        // listToAttrs (
          mapAttrsToList (
            backupName: backupConfig:
            let
              copies = backupCopyServices backupName;
            in
            {
              name = "restic-backups-${backupName}";
              value = mkIf (copies != [ ]) {
                unitConfig = {
                  OnSuccess = mkForce (concatStringsSep " " copies);
                };
              };
            }
          ) cfg.backups
        );
    };
}
