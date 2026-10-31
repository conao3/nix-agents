{ pkgs, agentsLib, ... }:
{
  home = {
    username = "example";
    homeDirectory = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/example" else "/home/example";
    stateVersion = "25.11";
  };

  programs.agents = {
    enable = true;
    instructions = pkgs.writeText "AGENTS.md" "Shared instructions for every agent.\n";
    common = {
      ensureFiles = [ "MEMORY.md" ];
      directories = [ "notes" ];
    };

    types = {
      claude = {
        executable = "${pkgs.hello}/bin/hello";
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
            env.DISABLE_TELEMETRY = agentsLib.migrate {
              from = "1";
              to = "";
            };
            defaultMode = agentsLib.delete;
            statusLine = agentsLib.force {
              type = "command";
              command = "echo status";
            };
          };
          ".claude.json" = {
            scope = "instances";
            extraTargets = [ ".claude.json" ];
          };
        };
      };
      codex = {
        executable = "${pkgs.hello}/bin/hello";
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
            approval_policy = "never";
            features = agentsLib.force { goals = true; };
          };
        };
      };
      cursor-agent = {
        executable = "${pkgs.hello}/bin/hello";
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
      "claude.work" = { };
      "claude.worker" = {
        share = false;
        instructions = pkgs.writeText "AGENTS-worker.md" "Instructions for unattended runs.\n";
      };
      "codex.personal".extraWrappers."codex.alt".makeWrapperArgs = [
        "--add-flags"
        "-p alt"
      ];
      "cursor-agent.personal" = { };
    };

    aliases.cursor-agent = "cursor-agent.personal";

    mcpServers = {
      docs.url = "https://example.com/mcp";
      tracker = {
        url = "https://tracker.example.com/mcp";
        bearerTokenEnvVar = "TRACKER_API_KEY";
      };
      vault = {
        url = "https://vault.example.com/mcp";
        bearerTokenFile = "~/.config/vault/key";
        enableFor = [ "claude" ];
      };
      local = {
        url = "http://127.0.0.1:3733/mcp";
        service = {
          description = "Local MCP server shared by every agent";
          execStart = "${pkgs.hello}/bin/hello";
        };
      };
    };

    zshFunctions.codex = "CODEX_WRAPPED=1 command codex.personal";
  };
}
