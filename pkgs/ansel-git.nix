# nixpkgs' own ansel is pinned to a commit from 2026-05-08; master moves
# fast (1758 commits ahead as of 2026-10-09). This overrides just src and
# version on top of nixpkgs' derivation -- same buildInputs, same patches,
# same cmakeFlags, all of which nixpkgs already maintains correctly -- so
# this only needs to track the one thing nixpkgs lags on.
#
# To bump: cd ../ansel (or wherever the checkout lives), note the commit and
# date of the revision to track, then update rev/version/hash below. Get the
# hash with a throwaway build using lib.fakeHash and reading the real one
# from the mismatch error.
{
  ansel,
  fetchFromGitHub,
  fetchpatch,
  glib,
  lib,
}:
ansel.overrideAttrs (old: {
  version = "0-unstable-2026-10-13";

  src = fetchFromGitHub {
    owner = "aurelienpierreeng";
    repo = "ansel";
    rev = "73ec46a31bf2c7335f217638de4d9e973b372049";
    hash = "sha256-bVbGf4M/eBO0FSDmNewQk/k8VU/T4kQpglPsDuQDuqM=";
    fetchSubmodules = true;
  };

  # Not yet merged upstream: sergiusens/ansel@b2e7b56 on top of the pinned
  # rev above. Keeps keyboard-moved selection in sync in the thumbtable grid.
  patches = (old.patches or [ ]) ++ [
    (fetchpatch {
      url = "https://github.com/sergiusens/ansel/commit/b2e7b56bbe1683d658a98a63bc03f3c5c4e751bc.patch";
      hash = "sha256-Sy2xIWmZN+MuaUlQLPtKxwVMzaBGLtFmKvalRGCmlz8=";
    })
  ];

  # New since nixpkgs' pin: src/libs/collect.c includes <gio/gunixmounts.h>,
  # which lives under glib's versioned gio-unix-2.0/ include subdirectory
  # rather than the plain include/ that buildInputs puts on the search path
  # automatically. ansel's own CMakeLists.txt does not declare a pkg-config
  # dependency on gio-unix-2.0 to pull that path in, so add it directly.
  env = (old.env or { }) // {
    NIX_CFLAGS_COMPILE = "${
      old.env.NIX_CFLAGS_COMPILE or ""
    } -I${lib.getDev glib}/include/gio-unix-2.0";
  };
})
