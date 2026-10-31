{ pkgs, lib, ... }:
{
  programs.agents = {
    enable = true;

    types.codex = {
      package = pkgs.codex;
      envVar = "CODEX_HOME";
      homeDir = ".codex";
      mcp = {
        format = "codex";
        key = "mcp_servers";
        files = [ "config.toml" ];
      };
      files."config.toml".onConflict = "overwrite";
    };

    instances."codex.personal".extraWrappers."codex.fast".makeWrapperArgs = [
      "--add-flags"
      "-p fast"
    ];

    aliases.codex-default = "codex.personal";

    zshFunctions.cx = "codex.personal";

    mcpServers.playwright = {
      url = "http://127.0.0.1:3733/mcp";
      service = {
        description = "Playwright MCP server shared by every agent";
        execStart = "${lib.getExe pkgs.playwright-mcp} --headless --host 127.0.0.1 --port 3733";
      };
    };
  };
}
