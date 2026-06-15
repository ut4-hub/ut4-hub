# Asserts the services.ut4Hub module evaluates to a valid systemd unit
# definition. Uses a fake server package so we don't need to build ut4-base.
#
# Run: nix eval --raw -f tests/module-eval.nix
(
  {
    pkgs ? import <nixpkgs> {
      config.allowUnfree = true;
    },
    lib ? pkgs.lib,
  }:
  let
    fakeServer = pkgs.runCommand "fake-ut4-server" { } ''
      mkdir -p $out/bin
      cat > $out/bin/ut4-server <<'EOF'
      #!/usr/bin/env bash
      echo "fake ut4-server"
      EOF
      chmod +x $out/bin/ut4-server
    '';

    fakeToken = pkgs.writeText "fake-token" "test-token-12345";

    eval = lib.evalModules {
      modules = [
        ../modules/ut4-hub-server.nix
        # Stub network.firewall option set with a default since we don't import
        # the full nixos modules in this eval-only test.
        {
          options.networking.firewall = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
          options.systemd.services = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
          options.users.users = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
          options.users.groups = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
        }
        {
          services.ut4Hub = {
            enable = true;
            package = fakeServer;
            serverName = "Test Hub";
            masterServer.domain = "master-ut4.timiimit.com";
            masterServer.tokenFile = fakeToken;
          };
        }
      ];
      specialArgs = { inherit pkgs; };
    };
  in
  assert eval.config.systemd.services ? ut4-hub;
  assert eval.config.systemd.services.ut4-hub.serviceConfig.Type == "simple";
  assert eval.config.users.users ? ut4;
  "ok"
)
{ }
