self: {
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.types) str;

  pterodactlyPhp81 = pkgs.php81.buildEnv {
    extensions = {
      enabled,
      all,
    }:
      enabled ++ (with all; [redis xdebug]);

    extraConfig = ''
      xdebug.mode=debug
    '';
  };

  cfg = config.services.pterodactyl;
in {
  options.services.pterodactyl = {
    enable = mkEnableOption "pterodactyl panel";

    user = mkOption {
      type = str;
      default = "pterodactyl";
      description = "The user under which the panel will run";
    };

    group = mkOption {
      type = str;
      default = "pterodactyl";
      description = "The group under which the panel will run";
    };

    dataDir = mkOption {
      type = str;
      default = "/var/www/pterodactyl";
      description = ''
        The directory with the panel files.
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge (
    (mkIf (cfg.user == "pterodactyl") {
      users.users.${cfg.user} = {
        isSystemUser = true;
        createHome = true;
        home = cfg.dataDir;
        group = cfg.user;
      };

      users.groups.${cfg.group} = {};
    })
    {
      services.phpfpm.pools.pterodactyl = {
        user = cfg.user;
        settings = {
          "listen.owner" = config.services.nginx.user;
          "pm" = "dynamic";
          "pm.start_servers" = 4;
          "pm.min_spare_servers" = 4;
          "pm.max_spare_servers" = 16;
          "pm.max_children" = 64;
          "pm.max_requests" = 256;

          "clear_env" = false;
          "catch_workers_output" = true;
          "decorate_workers_output" = false;
          "php_admin_value[error_log]" = "stderr";
          "php_admin_flag[daemonize]" = "false";
        };
      };

      systemd.services.pteroq = {
        enable = true;
        description = "Pterodactyl Queue Worker";
        after = ["redis-${cfg.redisName}.service"];
        unitConfig = {StartLimitInterval = 180;};
        path = [
          pterodactlyPhp81
          # composer
          (pkgs.php81Packages.composer.override {php = pterodactlyPhp81;})
        ];
        serviceConfig = {
          User = cfg.user;
          Group = cfg.user;
          Restart = "always";
          ExecStart = "${pterodactlyPhp81}/bin/php ${cfg.dataDir}/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3";
          StartLimitBurst = 30;
          RestartSec = "5s";
        };
        wantedBy = ["multi-user.target"];
      };
    }
  ));
}
