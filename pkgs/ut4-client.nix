# ut4-client: composed UT4 install (base + UT4UU + launcher + Engine.ini
# template). symlinkJoin merges the inputs under a single output dir; a
# postBuild step generates a bin/ut4 wrapper that bakes the symlinkJoin's $out
# into GAME_ROOT so the launcher resolves the install correctly.
{
  pkgs,
  ut4Base,
  ut4UU,
  engineIni,
  launcher,
}:
let
  # UT4UU's Files/ subtree mirrors the install tree, so we lay it down at
  # LinuxNoEditor/ under a new derivation that becomes a join input.
  ut4UULayer = pkgs.runCommand "ut4uu-layer" { } ''
    mkdir -p $out/LinuxNoEditor
    cp -r ${ut4UU}/Files/. $out/LinuxNoEditor/
  '';

  # Place the Engine.ini template under share/ut4-hub/ where the launcher
  # expects it.
  engineIniLayer = pkgs.runCommand "engine-ini-layer" { } ''
    mkdir -p $out/share/ut4-hub
    install -m 644 ${engineIni}/Engine.ini.template $out/share/ut4-hub/Engine.ini.template
  '';
in
pkgs.symlinkJoin {
  name = "ut4-client-xan-3525360";
  paths = [
    ut4Base
    ut4UULayer
    engineIniLayer
  ];

  # bin/ut4 wrapper: bakes $out (the join's path) into GAME_ROOT, then defers
  # to the launcher. We must generate this in postBuild because we need the
  # join's own output path.
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
    description = "Unreal Tournament 4 pre-alpha (Linux client) with UT4UU";
    mainProgram = "ut4";
    platforms = [ "x86_64-linux" ];
  };
}
