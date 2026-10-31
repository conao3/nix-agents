{ pkgs, agentsLib, ... }:
{
  programs.agents = {
    enable = true;
    instructions = ./AGENTS.md;
    warningsFile = ".claude/settings-warnings.log";

    types.claude = {
      package = pkgs.claude-code;
      envVar = "CLAUDE_CONFIG_DIR";
      homeDir = ".claude";
      instructionsFile = "CLAUDE.md";
      share = {
        enable = true;
        exclude = [
          ".claude.json"
          ".claude.json.tmp"
          ".claude.json.*"
          ".credentials.json"
        ];
        discard = [ "settings.json" ];
      };
      mcp = {
        format = "claude";
        key = "mcpServers";
        files = [
          "settings.json"
          ".claude.json"
        ];
      };
      files = {
        "settings.json".settings = {
          theme = "dark";
          permissions.defaultMode = "acceptEdits";
          env = {
            CLAUDE_CODE_ENABLE_TELEMETRY = "0";
            DISABLE_TELEMETRY = agentsLib.migrate {
              from = "1";
              to = "";
            };
          };
          hooks = agentsLib.force {
            SessionStart = [
              {
                matcher = "";
                hooks = [
                  {
                    type = "command";
                    command = "echo Read AGENTS.md before starting.";
                  }
                ];
              }
            ];
          };
        };
        ".claude.json" = {
          scope = "instances";
          extraTargets = [ ".claude.json" ];
        };
      };
    };

    types.codex = {
      package = pkgs.codex;
      envVar = "CODEX_HOME";
      homeDir = ".codex";
      share = {
        enable = true;
        exclude = [ "auth.json" ];
        history.sortKey = ".ts";
      };
      mcp = {
        format = "codex";
        key = "mcp_servers";
        files = [ "config.toml" ];
      };
      files."config.toml" = {
        onConflict = "overwrite";
        settings = {
          approval_policy = "on-request";
          sandbox_mode = "workspace-write";
        };
      };
    };

    instances = {
      "claude.personal" = { };
      "claude.work" = { };
      "codex.personal" = { };
    };

    aliases.codex-default = "codex.personal";

    mcpServers = {
      issues = {
        url = "https://mcp.example.com/issues";
        bearerTokenEnvVar = "ISSUES_API_KEY";
      };
      search = {
        url = "https://mcp.example.com/search";
        bearerTokenFile = "~/.config/search-mcp/key";
        enableFor = [ "claude" ];
      };
    };
  };
}
