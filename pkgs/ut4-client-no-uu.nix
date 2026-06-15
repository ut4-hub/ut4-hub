# ut4-client-no-uu: same composition as ut4-client minus the UT4UU layer.
# Useful for hubs that require stock UT4 (no plugin hooks).
{
  pkgs,
  ut4Base,
  engineIni,
  launcher,
}:
let
  engineIniLayer = pkgs.runCommand "engine-ini-layer" { } ''
    mkdir -p $out/share/ut4-hub
    install -m 644 ${engineIni}/Engine.ini.template $out/share/ut4-hub/Engine.ini.template
  '';
in
pkgs.symlinkJoin {
  name = "ut4-client-no-uu-xan-3525360";
  paths = [
    ut4Base
    engineIniLayer
  ];

  postBuild = ''
    mkdir -p $out/bin
    cat > $out/bin/ut4 <<EOF
    #!/usr/bin/env bash
    export GAME_ROOT="$out"
    exec ${launcher}/bin/ut4-launcher "\$@"
    EOF
    chmod +x $out/bin/ut4
  '';

  meta = {
    description = "Unreal Tournament 4 pre-alpha (Linux client, stock, no UT4UU)";
    mainProgram = "ut4";
    platforms = [ "x86_64-linux" ];
  };
}
