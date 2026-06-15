# ut4-server: dedicated-server package. Composes the server-base install
# (separately fetched from archive.org via ut4-server-base, NOT a reuse of
# the client zip) with a launcher wrapper that invokes
# UE4Server-Linux-Shipping under steam-run.
#
# Earlier this file reused ut4-base, on the assumption that the client zip
# also shipped UE4Server-Linux-Shipping. Empirically it doesn't — the
# server is a separate ~870MB archive.org artifact, and the extracted
# directory is LinuxServer/ (not LinuxNoEditor/).
#
# GAME_ROOT must be set by the caller (the services.ut4Hub module does this).
{ pkgs, ut4ServerBase }:
let
  serverLauncher = pkgs.writeShellApplication {
    name = "ut4-server";
    runtimeInputs = [ pkgs.steam-run ];
    text = ''
      set -euo pipefail
      : "''${GAME_ROOT:?GAME_ROOT not set; the services.ut4Hub module sets it}"

      GAME="''${GAME_ROOT}/LinuxServer"
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
    ut4ServerBase
    serverLauncher
  ];

  meta = {
    description = "Unreal Tournament 4 pre-alpha dedicated server";
    mainProgram = "ut4-server";
    platforms = [ "x86_64-linux" ];
  };
}
