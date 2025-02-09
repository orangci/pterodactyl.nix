self: {
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkForce mkMerge;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.types) attrsOf oneOf str bool int;

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
        The directory containing the panel files.

        For immutability reasons, we do not automatically unpack the panel, nor can we set
        the store directory
      '';
    };

    # Database Setup
    database = {
      mysql = {
        createLocally = mkOption {
          type = bool;
          default = false;
          description = ''
            Create the MySQL database and database user locally, and run installation.
          '';
        };

        options = mkOption {
          type = attrsOf (oneOf [
            str
            bool
            int
          ]);
          description = "MySQL database parameters";
          default = {
            host = "127.0.0.1";
            port = 3306;
            username = "pterodactyl";
            database = "panel";
            strict = false;
          };
        };
      };

      redis = {
        createLocally = mkOption {
          type = bool;
          default = false;
          description = ''
            Create the Redis database and database user locally, and run installation.
          '';
        };

        options = mkOption {
          type = attrsOf (oneOf [
            str
            bool
            int
          ]);
          description = "Redis database parameters";
          default = {
            username = "pterodactyl";
            database = "panel";
            password = "pterodactyl";
          };
        };
      };
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
      services = {
        mysql = mkIf cfg.database.mysql.createLocally {
          enable = true;
          ensureDatabases = [cfg.database.mysql.database];
          ensureUsers = [
            {
              name = cfg.database.mysql.username;
              ensurePermissions = {
                "${cfg.database.mysql.database}.*" = "ALL PRIVILEGES";
              };
            }
          ];
        };

        redis.servers."${cfg.database.redis.database}" = {
          enable = true;
          port = cfg.database.redis.port;
          user = cfg.database.redis.username;
          bind = cfg.database.redis.host;
          settings = {
            dir = mkForce "/var/lib/pterodactyl/redis";
            requirepass = cfg.database.redis.password;
          };
        };

        phpfpm.pools.pterodactyl = {
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
      };

      systemd.services.pteroq = {
        description = "Pterodactyl Queue Worker";
        requires = ["mysql.service" "redis-${cfg.database.redis.database}.service"];
        after = ["mysql.service" "redis-${cfg.database.redis.database}.service"];
        unitConfig = {StartLimitInterval = 180;};
        serviceConfig = {
          User = cfg.user;
          Group = cfg.user;
          Restart = "always";
          ExecStart = "${pterodactlyPhp81}/bin/php ${cfg.dataDir}/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3";
          StartLimitBurst = 30;
          RestartSec = "5s";
        };
        wantedBy = ["multi-user.target"];
        environment = [
          # Disable telemetry.
          "PTERODACTYL_TELEMETRY_ENABLED=false"
        ];
      };

      environment.systemPackages = [
        pterodactlyPhp81
        # composer
        (pkgs.php81Packages.composer.override {php = pterodactlyPhp81;})
      ];
    }
  ));
}
