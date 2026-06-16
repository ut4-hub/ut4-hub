# Source-rebuild plan (UT4 client, Linux)

Goal: produce a `libUE4-UnrealTournament-Linux-Shipping.so` with the
`#if PLATFORM_LINUX` early-returns removed from
`UTLocalPlayer::ToggleFriendsAndChat` (and the matching tooltip in
`SUTMenuBase::BuildOnlinePresence`). Side benefit: any other
PLATFORM_LINUX stub becomes recoverable too.

Three parallel approaches.

## Option 1 — Find someone with a 2017-era UE4 build cache

The blocker is the missing engine binary deps (1,285 4.15-specific packs
referenced in `Commit.gitdeps.xml`, none archived on wayback). Anyone who
actually built UE4 4.15 from source in 2017–2019 still has `Engine/Binaries/`
populated after Setup.sh ran. ~10 GB of files. We need them.

**People to ask** (most likely to have a working build env):

- **timiimit** ([github.com/timiimit](https://github.com/timiimit)) — author of
  the UT4MasterServer repo we forked. Almost certainly built the client at
  some point.
- **JimmieKJ** ([github.com/JimmieKJ/unrealtournament](https://github.com/JimmieKJ/unrealtournament))
  — maintains the UT4 source mirror we cloned. Likely has a working build.
- **Letgam3rs** ([github.com/Letgam3rs/UT4UU](https://github.com/Letgam3rs/UT4UU))
  — ships patched UT4UU binaries, has the build env.
- **Adam Rehn** ([adamrehn.com](https://adamrehn.com)) — author of `ue4-docker`,
  has extensive UE4 build infrastructure. May have an archived 4.15 image.

**Discord channels**:

- UT4 community Discord (linked from ut4.timiimit.com)
- ue4-docker Discord (Adam's tooling)

**Draft message** (copy-paste ready):

```
Hi — looking for someone who's built UT4 (UE4 4.15, CL 3228288) from
source on Linux and still has their populated Engine/Binaries/ tree
after Setup.sh / GitDependencies ran.

Background: cdn.unrealengine.com/dependencies/3228288-* returns 403
for me; wayback never archived those packs. I have all the C++ source
(JimmieKJ mirror) plus the v11_clang-5.0.0 toolchain (recovered from
wayback), but the build can't proceed without the prebuilt third-party
libs (UHT, UBT, libpng, freetype, FBX SDK, etc.) the dep system normally
fetches.

If anyone has that ~10 GB Engine/Binaries/ dir from a 2017–2019 build
and is willing to share, please reach out. Goal is to ship a Linux
build with friends-list + chat enabled again.

Thanks!
```

## Option 2 — Build third-party deps from source

If nobody has the cache, the long-form recovery: rebuild every dep from C++
source ourselves. UT4's third-party libs include (from `Engine/Source/ThirdParty`
inventory):

```
libpng, libcurl, freetype, hlslcc, OpenAL, OpenSSL, OpenSubdiv,
zlib, libjpeg, libogg, libvorbis, libwebsockets, ICU, ANGLE, PhysX,
Vorbis, GoogleVR, IntelTBB, libdSFMT, mcpp, MikkTSpace, ForsythTriOO,
Box2D, NVTextureTools, FastBuild, ShaderConductor, etc.
```

Each lib has its own `BuildLib_Linux.sh` in `Engine/Source/ThirdParty/<lib>/`
that downloads / builds against a specific clang. The work:

1. For each lib: run `BuildLib_Linux.sh` with the v11 toolchain wrappers
2. Some libs (PhysX, FBX SDK) are NOT open-source — Epic shipped prebuilt
   only. Those are **blockers**: no source available, no recovery without
   the original binaries.

PhysX 3.4 (FBX SDK, etc.) blockers make this option **probably impossible**
without violating EULAs.

## Option 3 — Surgical LD_PRELOAD (current path)

We already have `shims/ut4_friends_fix.cpp` building cleanly. The remaining
work is widget-mount-correct:

```
Current behaviour (commit 23d5aa0):
  - Vtable slot patched ✅
  - Replacement fires on click after 15s settle ✅
  - GetFriendsPopup returns popup TSharedPtr ✅
  - AddViewportWidgetContent called directly with popup → engine crash
    ~15 s later (likely TSharedRef expects an SOverlay-wrapped widget)

Open work:
  - Synthesise the SOverlay::FSlot wrap that the non-Linux source path uses
  - OR find a UE4 helper that takes a single TSharedRef<SWidget> and
    wraps it for AddViewportWidgetContent
  - OR skip viewport widget entirely and trigger the popup via a path that
    doesn't require manual mounting (e.g. SetShowingFriendsPopup + hope
    something else picks it up — needs investigation)
```

This is the most realistic 1-evening-of-work path. The downsides:
- Fragile (compiler upgrades, Slate internals)
- Doesn't generalize to other PLATFORM_LINUX stubs (each needs its own shim)
- Hard to ship to other users (per-machine setup)

## Toolchain artifacts recovered

For future reference / re-use:

- `native-linux-v11_clang-5.0.0-centos7.tar.gz`
- Source: `https://web.archive.org/web/20250906021627id_/https://cdn.unrealengine.com/Toolchain_Linux/native-linux-v11_clang-5.0.0-centos7.tar.gz`
- Size: 369 MB
- Local copy: `/tmp/ue4-toolchain-test/v11.tar.gz` (move to a permanent
  location before reboot)
- Wayback also has v12 (6.0.1), v15 (8.0.1), v16 (9.0.1), v17 (10.0.1),
  v19 (11.0.1), v20 (13.0.1). All are NEWER than the v8 (clang 3.9) that
  4.15 used; ABI compatibility with the shipping engine `.so` is unknown.

## Recommendation

Pursue option 1 (community ask) first — it's a 30-minute reach-out vs a
multi-week build effort. If that produces the cache, option 2 becomes
unnecessary. If option 1 fails, option 3 is the highest-ROI fallback for
the friends-list specifically.
