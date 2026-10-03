# herdr — terminal workspace manager for coding agents.
#
# herdr is a MULTIPLEXER, not an agent. It detects claude-code, codex, amp and
# others by process name and output pattern, and groups each pane as blocked /
# working / done / idle in a sidebar. It runs claude-code; it does not replace it.
#
# Shape and the non-obvious settings below are taken from a colleague's much
# deeper configuration, which also carries custom layout and quota plugins that
# are not public:
#   https://github.com/wimpysworld/nix-config  home-manager/_mixins/terminal/herdr.nix
{ config, pkgs, ... }:
let
  tomlFormat = pkgs.formats.toml { };
in
{
  xdg.configFile."herdr/config.toml".source = tomlFormat.generate "herdr-config.toml" {
    # THE important one. herdr shows its onboarding screen until it writes
    # `onboarding = false` back into this file — but Nix renders it as a
    # read-only symlink into the store, so herdr can never record completion
    # and would show onboarding on every single start. Pre-set it here.
    onboarding = false;

    # Ghostty implements the Kitty graphics protocol, so panes can draw images.
    terminal.kitty_graphics = true;

    # After a server restart, bring panes back as plain shells rather than
    # reviving agent conversations: restarted agents cost more attention than
    # they save.
    session.resume_agents_on_restore = false;

    ui = {
      agent_panel_sort = "spaces";
      status_indicators = "symbols";
      show_agent_labels_on_pane_borders = true;
      sound.enabled = false;
      toast.delivery = "system";

      sidebar.spaces.rows = [
        [
          "state_icon"
          "workspace"
        ]
        [
          "branch"
          "git_status"
        ]
      ];

      sidebar.agents.rows = [
        [
          "state_icon"
          {
            token = "$title";
            bold = true;
          }
        ]
        [
          { token = "$provider"; }
          { token = "$limit"; }
        ]
        [ { token = "$context"; } ]
      ];
    };

    # herdr appends <repo-name>/<branch> to this root when creating worktrees.
    worktrees.directory = "${config.home.homeDirectory}/Dev/_worktrees";
  };
}
