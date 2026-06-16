# Dedicated-server base install: fetched separately from the client because
# archive.org hosts the server as a distinct ~870MB zip
# (UnrealTournament-Server-XAN-3525360-Linux.zip). The server zip extracts to
# LinuxServer/ (not LinuxNoEditor/).
#
# Patches applied:
#   - execstack cleared on RWE .so files (kernel refuses RWE GNU_STACK)
#   - UE4Server-Linux-Shipping chmod +x
#   - AUTPartyBeaconHost::ProcessReservationRequest IsValid bypass
#     (see partyBeaconPatchOffset below for rationale)
{ pkgs }:
let
  inherit (pkgs)
    stdenv
    lib
    fetchurl
    unzip
    coreutils
    ;
  # `--clear-execstack` was added in patchelf 0.18 (nixpkgs default is 0.15).
  patchelf = pkgs.patchelfUnstable;

  build = "xan-3525360";
  upstreamUrl =
    "https://archive.org/download/unreal-tournament-4-pre-alpha/"
    + "UnrealTournament-Server-XAN-3525360-Linux.zip";
  # Hash verified locally on 2026-06-15 against archive.org artifact.
  upstreamSha256 = "sha256-dS/l3IYrWLhTDv3sFLybCpMneu2NaNysCZQ84vNKrPM=";

  # AUTPartyBeaconHost::ProcessReservationRequest at virtual address 0x1036b10
  # in libUE4Server-UnrealTournament-Linux-Shipping.so has this prologue:
  #
  #   mov    rax,QWORD PTR [rdi+0x510]   # rax = this->UTState
  #   test   rax,rax
  #   je     deny                         # null check
  #   cmp    DWORD PTR [rax+0x88],0xffffffff   # ReservationData.PlaylistId == -1?
  #   je     deny                         # IsValid() check  ← we NOP this je
  #   ...accept path (tail-calls parent ProcessReservationRequest)
  #   deny: ...sends ClientReservationResponse(Denied)
  #
  # The IsValid() check rejects any reservation against a Ranked server whose
  # UTState->ReservationData hasn't been seeded with a valid PlaylistId.
  # ReservationData only ever gets seeded by ProcessEmptyServerReservationRequest,
  # which the public Quick Play tile matchmaker never invokes (the CreateNew
  # path is exclusive to Blueprint code in UMatchmakingContext which is not
  # in the public UT4 source — verified via gh code search). Without this
  # patch, the matchmaker submits a reservation request, gets denied, and
  # restarts forever; with it, Quick Play tile lands cleanly into a real
  # AUTGameSessionRanked match.
  #
  # The patch: at file offset 0x1036b2f (== virtual address in .text since
  # .text loads at file offset = VA), change the 2 bytes `74 11` (JE +0x11)
  # to `90 90` (NOP NOP). The null check at 0x1036b26 is preserved so a
  # genuinely-null UTState still falls through to the denial path instead of
  # crashing on the cmpl.
  #
  # The verify-then-patch dance below fails the build loudly if the bytes
  # at that offset don't match, so a future upstream-binary update will
  # surface as a build error rather than silently breaking Quick Play.
  partyBeaconPatchOffset = "0x1036b2f";
  partyBeaconPatchExpected = "\\x74\\x11";
  partyBeaconPatchReplacement = "\\x90\\x90";
in
stdenv.mkDerivation {
  name = "ut4-server-base-${build}";

  src = fetchurl {
    url = upstreamUrl;
    sha256 = upstreamSha256;
  };

  nativeBuildInputs = [
    unzip
    patchelf
    coreutils
  ];

  unpackPhase = ''
    runHook preUnpack
    unzip -q $src
    runHook postUnpack
  '';

  buildPhase = ''
    runHook preBuild
    # Clear executable-stack flag on every .so that has GNU_STACK = RWE so
    # modern kernels accept the dlopen calls.
    find LinuxServer -type f -name '*.so' | while read -r so; do
      if readelf -lW "$so" 2>/dev/null | awk '/GNU_STACK/ && $7=="RWE" {found=1} END{exit !found}'; then
        patchelf --clear-execstack "$so"
      fi
    done
    chmod +x LinuxServer/Engine/Binaries/Linux/UE4Server-Linux-Shipping

    # Apply the AUTPartyBeaconHost::ProcessReservationRequest IsValid bypass.
    # See the partyBeaconPatchOffset comment block above for the full
    # rationale; the short version is: this two-byte NOP lets QuickPlay-tile
    # reservation requests succeed against an unconfigured Ranked server.
    utlib="LinuxServer/UnrealTournament/Binaries/Linux/libUE4Server-UnrealTournament-Linux-Shipping.so"

    # Verify the expected bytes are still there. If a future upstream
    # binary update shifts the offset, this dies loudly instead of
    # silently breaking matchmaking.
    actual=$(dd if="$utlib" bs=1 skip=$((${partyBeaconPatchOffset})) count=2 status=none | od -An -tx1 | tr -d ' \n')
    if [ "$actual" != "7411" ]; then
      echo "ut4-server-base: partyBeacon patch offset ${partyBeaconPatchOffset} expected '74 11' but saw '$actual'." >&2
      echo "  The upstream binary likely changed. Re-disassemble AUTPartyBeaconHost::ProcessReservationRequest and update partyBeaconPatchOffset." >&2
      exit 1
    fi
    printf '${partyBeaconPatchReplacement}' \
      | dd of="$utlib" bs=1 seek=$((${partyBeaconPatchOffset})) count=2 conv=notrunc status=none

    # Re-verify after the patch.
    after=$(dd if="$utlib" bs=1 skip=$((${partyBeaconPatchOffset})) count=2 status=none | od -An -tx1 | tr -d ' \n')
    if [ "$after" != "9090" ]; then
      echo "ut4-server-base: partyBeacon patch failed to apply, bytes are '$after'." >&2
      exit 1
    fi

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r LinuxServer $out/
    runHook postInstall
  '';

  meta = {
    description = "UT4 pre-alpha dedicated server install (XAN-3525360, Linux)";
    homepage = "https://archive.org/details/unreal-tournament-4-pre-alpha";
    platforms = [ "x86_64-linux" ];
    license = lib.licenses.unfree;
  };

  passthru = {
    inherit upstreamUrl upstreamSha256 build;
  };
}
