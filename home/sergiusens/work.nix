# Chainguard work tooling. Imported by hosts/kynes only.
#
# Translated from eregion's Homebrew leaves (`brew leaves` under Bluefin,
# 2026-10-06), keeping the work tools and leaving shell preferences to the
# shared home. Not here, on purpose:
#   cg     internal CLI from a private tap; it self-updates in ~/.local/bin
#   claude system-wide, modules/profiles/desktop-apps.nix
#   docker system-wide, hosts/kynes/default.nix
#
# Claude Code's managed settings come from IT's
# chainguard-sandbox/claude-managed-settings `deploy.sh`, which writes
# /etc/claude-code/managed-settings.json. NixOS does not manage that path, so
# run the script as on any other distro. Do not reproduce its content here:
# IT updates it, and the repository is internal.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    # --- Chainguard / supply chain -----------------------------------------
    chainctl # local derivation, pkgs/chainctl.nix
    crane
    cosign
    gitsign
    grype
    syft

    # --- cloud and clusters ------------------------------------------------
    (google-cloud-sdk.withExtraComponents [
      google-cloud-sdk.components.gke-gcloud-auth-plugin
    ])
    gcsfuse
    kubectl
    kubectx
    argo-workflows # the `argo` CLI
    terraform # unfree (BSL)

    # --- languages and linters ---------------------------------------------
    go
    gopls
    gotools # goimports
    golangci-lint
    uv
    pre-commit
    shellcheck
    dbmate

    # --- secrets and keys --------------------------------------------------
    age
    age-plugin-yubikey
    sops
    yubikey-manager # ykman

    # --- everyday CLI ------------------------------------------------------
    delta
    tig
    yq-go
  ];

  # chainctl comes from the Nix store, read-only and pinned, so its update nag
  # can only be silenced, not acted on. Bump pkgs/chainctl.nix instead.
  #
  # Edits the one key in place rather than declaring the file: config.yaml
  # also holds org, auth and output settings managed through chainctl itself.
  # From wimpysworld/nix-config's development/chainguard mixin.
  home.activation.chainctlSkipVersionCheck = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    chainctl_config=${lib.escapeShellArg "${config.xdg.configHome}/chainctl/config.yaml"}
    if [[ ! -e "$chainctl_config" ]]; then
      run ${pkgs.coreutils}/bin/install -Dm600 /dev/null "$chainctl_config"
    fi
    run ${pkgs.yq-go}/bin/yq -i '.default.skip-version-check = true' "$chainctl_config"
  '';

  # Work commits carry the work address; the shared default is personal.
  programs.git.settings = {
    user.email = lib.mkForce "sergio.schvezov@chainguard.dev";
    # As on eregion.
    core.pager = "delta";
    delta.side-by-side = true;
  };
}
