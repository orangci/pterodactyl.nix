self: {
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.types) nullOr package str path;

  format = pkgs.formats.yaml {};
  cfg = config.services.wings;
in {
  options.services.wings = {
    enable = mkEnableOption "Wings daemon";
    package = mkOption {
      type = package;
      description = "Package to use for the Wings daemon";
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.pterodactyl-wings;
    };

    user = mkOption {
      type = str;
      description = "The user to run the Pterodactyl Wings daemon as";
      default = "pterodactyl";
    };

    group = mkOption {
      type = str;
      description = "The group under which the Wings daemon will run";
      default = "pterodactyl";
    };

    tokenFile = mkOption {
      type = nullOr path;
      default = null;
      description = "The file to store the Pterodactyl Wings daemon token in";
    };

    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      description = lib.mdDoc "The path to the Pterodactyl Wings daemon configuration file";
      default = null;
    };

    rootDirectory = mkOption {
      type = str;
      default = "/var/lib/pterodactyl";
      description = "Root directory for Pterodactyl.";
    };

    logDirectory = mkOption {
      type = str;
      default = "/var/log/pterodactyl";
      description = "Log directory for Pterodactyl.";
    };

    data = mkOption {
      type = str;
      default = "/var/lib/pterodactyl/volumes";
      description = "Data directory for Pterodactyl.";
    };

    archiveDirectory = mkOption {
      type = str;
      default = "/var/lib/pterodactyl/archives";
      description = "Archive directory for Pterodactyl.";
    };

    backupDirectory = mkOption {
      type = str;
      default = "/var/lib/pterodactyl/backups";
      description = "Backup directory for Pterodactyl.";
    };

    config = mkOption {
      type = nullOr format.type;
      default = {
        RootDirectory = cfg.rootDirectory;
        LogDirectory = cfg.logDirectory;
        Data = cfg.dataDirectory;
        ArchiveDirectory = cfg.archiveDirectory;
        BackupDirectory = cfg.backupDirectory;
      };

      description = ''
        The configuration for the Wings daemon.

        :::{.note}
        Pterodactyl does not have any documentation on configuring the Wings daemon. For available options
        you must refer to the program's [source code](https://github.com/pterodactyl/wings/blob/develop/config/config.go#L64-L329)
        :::
      '';
    };

    generatedConfig = mkOption {
      internal = true;
      visible = false;
      type = format.type;
      default = format.generate "config.yml" cfg.config;
      description = "Processed configuration.";
    };
  };
  config = mkIf cfg.enable (mkMerge (
    (mkIf (cfg.user == "pterodactyl") {
      users.users = {
        pterodactyl = {
          name = "pterodactyl";
          group = cfg.group;
          isSystemUser = true;
        };
      };

      users.groups = {
        pterodactyl = {
          name = "pterodactyl";
        };
      };
    })
    {
      # TODO: this is only compatible with Pterodactyl for now. We *can* make this configurable
      # by expecting the user to provide each directory, so that it is somewhat uniform.
      systemd.tmpfiles.rules = [
        "d /var/log/pterodactyl 0700 ${cfg.user} ${cfg.group}"
        "d /var/lib/pterodactyl 0700 ${cfg.user} ${cfg.group}"
        "d /etc/pterodactyl 0700 ${cfg.user} ${cfg.group}"
      ];

      systemd.services.wings = {
        description = "Wings pterodactyl daemon";
        wantedBy = ["multi-user.target"];

        preStart = let
          readToken = pkgs.writeShellApplication {
            name = "wings-read-token";
            script = ''
              token=$(cat ${cfg.tokenFile})
              cat > /etc/pterodactyl/config.yml << EOF
              token: $token
              ${builtins.readFile cfg.generatedConfig}
              EOF
            '';
          };
        in
          mkIf (cfg.tokenFile != null) ''
            exec ${readToken}

            chown ${cfg.user}:${cfg.group} /etc/pterodactyl/config.yml

            exit 0
          '';

        serviceConfig = {
          User = cfg.user;
          Group = cfg.group;

          ExecStart = "${cfg.package}/bin/wings --config ${
            if cfg.tokenFile != null
            then "/etc/pterodactyl/config.yml"
            else if cfg.configFile != null
            then cfg.configFile
            else cfg.generatedConfig
          }";

          Restart = "on-failure";
        };
      };
    }
  ));
}
