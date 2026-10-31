{ pkgs, ... }:
{
  programs.agents = {
    enable = true;

    types = {
      claude = {
        package = pkgs.claude-code;
        envVar = "CLAUDE_CONFIG_DIR";
        homeDir = ".claude";
        instructionsFile = "CLAUDE.md";
      };
      codex = {
        package = pkgs.codex;
        envVar = "CODEX_HOME";
        homeDir = ".codex";
      };
      pi = {
        package = pkgs.pi-coding-agent;
        envVar = "PI_CODING_AGENT_DIR";
      };
      cursor-agent = {
        package = pkgs.cursor-cli;
        envVar = "CURSOR_HOME";
        mcp = {
          format = "cursor";
          key = "mcpServers";
          files = [ "mcp.json" ];
        };
        files."mcp.json" = {
          scope = "instances";
          strategy = "overwrite";
        };
      };
    };

    instances = {
      "claude.personal" = { };
      "codex.personal" = { };
      "pi.personal" = { };
      "cursor-agent.personal" = { };
    };
  };
}
