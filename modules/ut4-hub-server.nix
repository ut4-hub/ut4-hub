# NixOS module that runs a UT4 dedicated server (hub or single-match) as a
# systemd service. The master-server token is provided as a *file path* —
# never inline — so the module pairs cleanly with sops-nix / agenix.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.ut4Hub;

  stateDir = "/var/lib/ut4-hub";

  # Server-side Engine.ini: same MCP redirect we use client-side, but written
  # to LinuxServer (not LinuxNoEditor).
  engineIniText = ''
    [OnlineSubsystemMcp.BaseServiceMcp]
    Protocol=https
    Domain=${cfg.masterServer.domain}
    EngineName=UE4
    ServiceName=entitlement
    GameName=UnrealTournament

    [OnlineSubsystemMcp.GameServiceMcp]
    Protocol=https
    Domain=${cfg.masterServer.domain}
    ServiceName=ut
    GameName=UnrealTournament

    [OnlineSubsystemMcp.AccountServiceMcp]
    Protocol=https
    Domain=${cfg.masterServer.domain}
    ServiceName=account
    GameName=UnrealTournament

    [OnlineSubsystemMcp.OnlineFriendsMcp]
    Protocol=https
    Domain=${cfg.masterServer.domain}
    ServiceName=friends
    GameName=UnrealTournament

    [OnlineSubsystemMcp.PersonaServiceMcp]
    Domain=${cfg.masterServer.domain}

    [OnlineSubsystemMcp.OnlineImageServiceMcp]
    Protocol=https
    Domain=${cfg.masterServer.domain}

    [OnlineSubsystemMcp.ContentControlsServiceMcp]
    Protocol=https
    Domain=${cfg.masterServer.domain}
  '';

  engineIniFile = pkgs.writeText "ut4-hub-Engine.ini" engineIniText;

  serverArgs = [
    "UnrealTournament"
    "${cfg.initialMap}?Game=${cfg.initialGame}?MaxPlayers=${toString cfg.maxPlayers}?listen"
    "-SaveToUserDir"
    "-server"
    "-Port=${toString cfg.ports.game}"
    "-QueryPort=${toString cfg.ports.query}"
    "-BeaconPort=${toString cfg.ports.beacon}"
  ]
  ++ cfg.extraArgs;
in
{
  options.services.ut4Hub = {
    enable = lib.mkEnableOption "Unreal Tournament 4 dedicated hub/server";

    package = lib.mkOption {
      type = lib.types.package;
      description = "ut4-server package to run (typically `pkgs.ut4-hub.ut4-server`).";
    };

    mode = lib.mkOption {
      type = lib.types.enum [
        "hub"
        "server"
      ];
      default = "hub";
      description = "Hub (lobby spawning instances) or single-match server.";
    };

    serverName = lib.mkOption {
      type = lib.types.str;
      description = "Public-facing server name.";
    };

    masterServer = {
      domain = lib.mkOption {
        type = lib.types.str;
        example = "master-ut4.timiimit.com";
        description = "Domain of the master server to register with.";
      };
      tokenFile = lib.mkOption {
        type = lib.types.path;
        description = ''
          Path to a file containing the master-server registration token.
          Use sops-nix or agenix — never inline the token literal in Nix.
        '';
      };
    };

    initialMap = lib.mkOption {
      type = lib.types.str;
      default = "UT-Entry";
      description = "Initial map. UT-Entry is the canonical hub entry.";
    };

    initialGame = lib.mkOption {
      type = lib.types.str;
      default = "Lobby";
      example = "CTF";
      description = "Initial game mode.";
    };

    maxPlayers = lib.mkOption {
      type = lib.types.ints.positive;
      default = 50;
    };

    ports = {
      game = lib.mkOption {
        type = lib.types.port;
        default = 7777;
      };
      query = lib.mkOption {
        type = lib.types.port;
        default = 7787;
      };
      beacon = lib.mkOption {
        type = lib.types.port;
        default = 15000;
      };
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open ports {game,query,beacon}/udp in the firewall.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra command-line arguments passed to UE4Server-Linux-Shipping.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.ut4 = {
      isSystemUser = true;
      group = "ut4";
      home = stateDir;
      createHome = true;
    };
    users.groups.ut4 = { };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedUDPPorts = [
        cfg.ports.game
        cfg.ports.query
        cfg.ports.beacon
      ];
    };

    systemd.services.ut4-hub = {
      description = "Unreal Tournament 4 dedicated server (${cfg.serverName})";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        set -eu
        CFG_DIR="${stateDir}/Documents/UnrealTournament/Saved/Config/LinuxServer"
        mkdir -p "$CFG_DIR"
        cp -f ${engineIniFile} "$CFG_DIR/Engine.ini"
        TOKEN=$(cat ${cfg.masterServer.tokenFile})
        cat > "$CFG_DIR/Server.ini" <<EOF
        [Server]
        Name=${cfg.serverName}
        MasterServerToken=$TOKEN
        EOF
        chown -R ut4:ut4 "${stateDir}"
      '';

      serviceConfig = {
        Type = "simple";
        User = "ut4";
        Group = "ut4";
        ExecStart = "${cfg.package}/bin/ut4-server ${lib.concatStringsSep " " serverArgs}";
        Restart = "on-failure";
        RestartSec = "10s";
        WorkingDirectory = stateDir;
        Environment = [
          "GAME_ROOT=${cfg.package}"
          "HOME=${stateDir}"
        ];
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
        ReadWritePaths = [ stateDir ];
      };
    };
  };
}
