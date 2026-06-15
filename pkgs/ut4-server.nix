# ut4-server: the dedicated-server side. The client install already contains
# Engine/Binaries/Linux/UE4Server-Linux-Shipping, so this reuses ut4-base and
# just provides a different launch entry point.
#
# The NixOS module (services.ut4Hub) sets GAME_ROOT for the systemd unit; this
# package on its own is rarely invoked directly.
{ pkgs, ut4Base }:
let
  serverLauncher = pkgs.writeShellApplication {
    name = "ut4-server";
    runtimeInputs = [ pkgs.steam-run ];
    text = ''
      set -euo pipefail
      : "''${GAME_ROOT:?GAME_ROOT not set; the services.ut4Hub module sets it}"

      GAME="''${GAME_ROOT}/LinuxNoEditor"
      BIN="''${GAME}/Engine/Binaries/Linux/UE4Server-Linux-Shipping"
      if [[ ! -x "''${BIN}" ]]; then
        echo "UT4 server binary missing or non-executable: ''${BIN}" >&2
        exit 1
      fi

      ENGINE_LIB="''${GAME}/Engine/Binaries/Linux"
      cd "''${GAME}"
      LD_LIBRARY_PATH="''${ENGINE_LIB}:''${LD_LIBRARY_PATH:-}" \
      exec ${pkgs.steam-run}/bin/steam-run "''${BIN}" "$@"
    '';
  };
in
pkgs.symlinkJoin {
  name = "ut4-server-xan-3525360";
  paths = [
    ut4Base
    serverLauncher
  ];

  meta = {
    description = "Unreal Tournament 4 pre-alpha dedicated server";
    mainProgram = "ut4-server";
    platforms = [ "x86_64-linux" ];
  };
}
