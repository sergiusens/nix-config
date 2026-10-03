# Déjà Dup backup configuration, carried over from the Bluefin system.
#
# It was a Flatpak there (org.gnome.DejaDup 50.2 from Flathub), so its settings
# lived in the sandbox at
# ~/.var/app/org.gnome.DejaDup/config/glib-2.0/settings/keyfile rather than in
# host dconf — which is why `gsettings list-recursively` found nothing on the
# host. Values below were read out of the running Flatpak.
#
# The exclude-list contains $HOME itself alongside an include-list of $HOME.
# That looks self-defeating, but the running configuration demonstrably backs up
# and restores — Déjà Dup reports "Folders: Home (sergiusens)" and the archive
# browses fine — so the entry is inert in practice. Most likely duplicity's
# selection rules are first-match-wins and the include is reached first, but the
# mechanism has not been confirmed.
#
# It is reproduced verbatim (path-translated) rather than cleaned up, because
# this configuration is known to work and the point of porting it is to keep it
# working. Do not "fix" it without testing a restore.
{
  dconf.settings = {
    "org/gnome/deja-dup" = {
      backend = "remote";

      include-list = [ "$HOME" ];

      # Paths rewritten from /var/home/sergiusens (ostree) to $HOME-relative
      # form. Using $HOME rather than an absolute path means these survive a
      # move to another machine or user name unchanged — including the $HOME
      # entry itself, which on Bluefin read /var/home/sergiusens.
      exclude-list = [
        "$TRASH"
        "$DOWNLOAD"
        "$HOME"
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
