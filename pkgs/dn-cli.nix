# dn ("dn-cli" on crates.io): a Denote-inspired CLI for naming and renaming
# plaintext notes with timestamped filenames.
#
# Packaged from crates.io rather than fetchFromGitHub. Upstream's own
# default.nix (shipped inside the crate tarball) fetches github.com/mmibbetson/dn
# at tag v0.1.3, but that repository is gone — the account now shows a single
# public repo, and the tag resolves to a 404. The crate itself is still
# published and unyanked, and its tarball carries everything the build needs
# (Cargo.lock, man page sources, shell completions), so build from that instead.
{
  lib,
  rustPlatform,
  fetchCrate,
  installShellFiles,
}:

rustPlatform.buildRustPackage rec {
  pname = "dn";
  version = "0.1.3";

  src = fetchCrate {
    pname = "dn-cli";
    inherit version;
    hash = "sha256-J5Tkx8metnCLFsiAV4aCMFRcaaum4jMufYIQOAado5I=";
  };

  cargoHash = "sha256-1QBscWl3haIWNyWig4SkhUVCmWhU5n4SCoBNduuITto=";

  nativeBuildInputs = [ installShellFiles ];

  outputs = [
    "out"
    "man"
  ];

  postInstall = ''
    installManPage man/dn.1 man/dn-new.1 man/dn-rename.1
    installShellCompletion \
      --bash completions/dn.bash \
      --fish completions/dn.fish \
      --zsh completions/_dn
  '';

  meta = {
    description = "Simple, minimal, flexible command line utility for organising plaintext files with timestamped names";
    homepage = "https://mmibbetson.github.io/software/dn";
    license = lib.licenses.gpl3Plus;
    mainProgram = "dn";
    platforms = lib.platforms.unix;
  };
}
