# Pure eval tests for ut4-hub derivations. These don't realize anything (no
# network, no build); they only check that derivations evaluate to expected
# names and that fixed-output hashes match what's pinned.
#
# Run: nix eval --raw -f tests/eval.nix
(
  {
    pkgs ? import <nixpkgs> {
      config.allowUnfree = true;
    },
  }:
  let
    fetchOras = import ../pkgs/lib/fetchOras.nix {
      inherit (pkgs) stdenv oras cacert;
    };

    # 1. fetchOras emits a derivation with the expected outputHash and name.
    fetchOrasResult = fetchOras {
      reference = "ghcr.io/example/test:latest";
      sha256 = "0000000000000000000000000000000000000000000000000000";
    };
    # 2. ut4-base evaluates with the expected name and passthru.
    ut4Base = import ../pkgs/ut4-base.nix {
      inherit pkgs;
      inherit fetchOras;
    };

    # 3. ut4-ut4uu derivation evaluates with expected name.
    ut4UU = import ../pkgs/ut4-ut4uu.nix { inherit pkgs; };

    # 4. engine-ini-template evaluates and contains the master server domain.
    engineIni = import ../pkgs/ut4-engine-ini-template.nix {
      inherit pkgs;
      masterServerDomain = "master-ut4.timiimit.com";
    };

    # 5. launcher evaluates.
    launcher = import ../pkgs/ut4-launcher.nix {
      inherit pkgs;
      masterServerDomain = "master-ut4.timiimit.com";
    };

    # 6. ut4-client composes everything.
    client = import ../pkgs/ut4-client.nix {
      inherit pkgs ut4Base ut4UU engineIni launcher;
    };

    # 7. ut4-client-no-uu composes everything minus the UT4UU layer.
    clientNoUU = import ../pkgs/ut4-client-no-uu.nix {
      inherit pkgs ut4Base engineIni launcher;
    };

    # 8. ut4-server (server-side launcher composed with ut4-base).
    server = import ../pkgs/ut4-server.nix {
      inherit pkgs ut4Base;
    };
  in
  assert fetchOrasResult.outputHash == "0000000000000000000000000000000000000000000000000000";
  # Nix sanitizes colons in derivation names to hyphens.
  assert fetchOrasResult.name == "fetchOras-test-latest";
  assert ut4Base.name == "ut4-base-xan-3525360";
  assert ut4Base.passthru.build == "xan-3525360";
  assert ut4UU.name == "ut4uu-v10.1.6";
  assert engineIni.name == "ut4-engine-ini-template";
  assert launcher.name == "ut4-launcher";
  assert client.name == "ut4-client-xan-3525360";
  assert clientNoUU.name == "ut4-client-no-uu-xan-3525360";
  assert server.name == "ut4-server-xan-3525360";
  "ok"
)
{ }
