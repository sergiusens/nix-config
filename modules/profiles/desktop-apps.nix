# The application set common to the full desktop hosts (leto, kynes).
#
# Deliberately excludes anything photo- or hardware-specific: those live in the
# host file. Factored out so the two hosts cannot drift apart — the alternative
# was copying twenty package names and maintaining them twice.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # --- agents -----------------------------------------------------------
    claude-code
    # herdr is a terminal MULTIPLEXER for coding agents, not an agent: it
    # detects claude-code, codex, amp and others and shows each pane as
    # blocked/working/done/idle. It runs claude-code rather than replacing it.
    # Configured declaratively in home/sergiusens/herdr.nix.
    herdr
    claude-desktop # from the flake input; see the caveat in flake.nix

    # --- desktop ----------------------------------------------------------
    fractal # Matrix client; complements telegram-desktop and slack
    gnome-secrets # "Secrets": GNOME password manager, KeePass v4 format
    helix # editor
    frogmouth # Markdown browser in the terminal
    newsflash # RSS
    papers # the GTK4 document viewer that replaced Evince
    deja-dup # backups; see home/sergiusens/default.nix for why it's not configured here
    restic
    ticketbooth # film and TV tracker
    telegram-desktop
    slack # unfree
  ];

  # programs.firefox rather than the bare package: it wires up policies, native
  # messaging hosts and the desktop integration that a plain systemPackages
  # entry does not. Which browser is *default* is per-host, decided in
  # home/sergiusens/default.nix from hostName.
  programs.firefox.enable = true;
}
