# UT4UU drop-in overlay (Linux-targeted Files/ tree). The release zip contains
# a .NET CLI installer for Windows; we only ship the Files/ subtree which
# mirrors the install layout and can be merged at the right paths.
{ pkgs }:
let
  inherit (pkgs)
    stdenv
    lib
    fetchurl
    unzip
    ;
  version = "10.1.6";
in
stdenv.mkDerivation {
  name = "ut4uu-v${version}";
  inherit version;

  src = fetchurl {
    url = "https://github.com/timiimit/UT4UU-Public/releases/download/v${version}/UT4UU-v10_1_6.zip";
    sha256 = "0nwiym517s7dzzmy5lm1mh577yjk9xv4i2pmdzzlg0y1r2jswxkg";
  };

  nativeBuildInputs = [ unzip ];

  unpackPhase = ''
    runHook preUnpack
    unzip -q $src
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/Files
    # Note: the upstream zip uses underscores in the directory name (10_1_6),
    # not the dotted version (10.1.6).
    cp -r "UT4UU-v10_1_6/Installer/Files/." $out/Files/
    runHook postInstall
  '';

  meta = {
    description = "UT4UU v${version} drop-in overlay (Linux-targeted Files/ tree)";
    homepage = "https://github.com/timiimit/UT4UU-Public";
    platforms = [ "x86_64-linux" ];
    license = lib.licenses.unfreeRedistributable;
  };
}
