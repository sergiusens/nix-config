# chainctl: Chainguard's platform CLI. Proprietary, shipped only as a static
# binary from dl.enforce.dev.
#
# Local because nixpkgs does not have it yet. This is the derivation from the
# open nixpkgs PR (https://github.com/NixOS/nixpkgs/pull/519985, by a Chainguard
# customer, reviewed in #nixos), cut down to x86_64-linux. Once that PR lands in
# the pinned release, delete this file and the overlay line in flake.nix.
#
# Pinned and hashed on purpose. pg-cgr/chainctl-nix fetches the `latest`
# endpoint instead, which breaks with a hash mismatch every time upstream ships.
#
# To bump: take the version from `chainctl version` after its self-update, then
#   nix store prefetch-file https://dl.enforce.dev/chainctl/<version>/chainctl_linux_x86_64
{
  lib,
  stdenvNoCC,
  fetchurl,
  installShellFiles,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "chainctl";
  version = "0.2.369";

  src = fetchurl {
    url = "https://dl.enforce.dev/chainctl/${finalAttrs.version}/chainctl_linux_x86_64";
    hash = "sha256-bSetw/25xVi+DpWOh3tvpGh/S6Psdp4aUfnoZ+ndE94=";
  };

  dontUnpack = true;

  nativeBuildInputs = [
    installShellFiles
    writableTmpDirAsHomeHook
  ];

  installPhase = ''
    runHook preInstall
    install -Dm0755 "$src" "$out/bin/chainctl"

    # chainctl inspects argv[0] and acts as a Docker credential helper when
    # invoked as "docker-credential-cgr".
    ln -s chainctl "$out/bin/docker-credential-cgr"

    runHook postInstall
  '';

  postInstall = ''
    installShellCompletion --cmd chainctl \
      --bash <($out/bin/chainctl completion bash) \
      --zsh <($out/bin/chainctl completion zsh)
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckKeepEnvironment = [ "HOME" ];
  versionCheckProgramArg = "version";

  meta = {
    description = "Command-line interface for the Chainguard platform";
    homepage = "https://edu.chainguard.dev/chainguard/chainctl/";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "chainctl";
    platforms = [ "x86_64-linux" ];
  };
})
