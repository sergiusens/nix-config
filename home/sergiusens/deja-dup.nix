# Déjà Dup backup configuration, carried over from the Bluefin system.
#
# It was a Flatpak there (org.gnome.DejaDup 50.2 from Flathub), so its settings
# lived in the sandbox at
# ~/.var/app/org.gnome.DejaDup/config/glib-2.0/settings/keyfile rather than in
# host dconf — which is why `gsettings list-recursively` found nothing on the
# host. Values below were read out of the running Flatpak.
#
# ########################### READ THIS ONE THING ###########################
# The old exclude-list contained `/var/home/sergiusens` — the entire home
# directory — while include-list is `['$HOME']`. Excludes generally win over
# includes in duplicity, which would mean the backups have been covering
# approximately nothing. Supporting evidence: the last run went from start to
# finish in 88 seconds (23:20:50 -> 23:22:18), which is implausible for a
# 506 GB home even incrementally.
#
# That blanket exclude is NOT reproduced below, on the assumption it was added
# by accident through the folder picker. Everything else is faithful. If it was
# deliberate, put it back — but then the include-list needs rethinking too.
#
# VERIFY YOUR BACKUPS ACTUALLY CONTAIN FILES before trusting them, independently
# of this migration.
# ###########################################################################
{
  dconf.settings = {
    "org/gnome/deja-dup" = {
      backend = "remote";

      include-list = [ "$HOME" ];

      # Paths rewritten from /var/home/sergiusens (ostree) to $HOME-relative
      # form. Using $HOME rather than an absolute path means this survives a
      # move to another machine or user name unchanged.
      exclude-list = [
        "$TRASH"
        "$DOWNLOAD"
        "$HOME/.cache"
        "$HOME/.local/share/containers"
        "$HOME/Música"
      ];

      periodic = true;
      periodic-period = 7;
      full-backup-period = 90;
      delete-after = 365;

      allow-metered = false;
      allow-power-saver = false;
    };

    # The NAS, reached over Tailscale rather than the LAN address, so backups
    # work away from home. Note this is the machine HOSTNAMES.md calls shadout
    # (was angrenost); the share name still carries the old host name cuivienen
    # and will want renaming to leto when convenient.
    "org/gnome/deja-dup/remote" = {
      uri = "smb://angrenost.great-torino.ts.net/cuivienen";
      folder = "deja-dup";
    };
  };
}
