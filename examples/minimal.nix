{ pkgs, ... }:
{
  programs.agents = {
    enable = true;

    types.claude = {
      package = pkgs.claude-code;
      envVar = "CLAUDE_CONFIG_DIR";
    };

    instances = {
      "claude.personal" = { };
      "claude.work" = { };
    };
  };
}
