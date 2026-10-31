# nix-agents

A home-manager module, `programs.agents`, for running coding agents (Claude Code, Codex, pi, cursor-agent, ...) as several *instances* on one machine. Each instance has its own configuration directory and its own wrapper executable; instances of the same program can share a directory for history, projects and settings; and configuration files that the agents rewrite themselves are merged on activation instead of being replaced by read-only symlinks.

The upstream home-manager modules (`programs.claude-code`, `programs.codex`, `programs.mcp`) link one configuration directory into the Nix store. This module covers what they leave out:

- several configuration directories per program, each selected by a wrapper that exports the program's directory variable (`CLAUDE_CONFIG_DIR`, `CODEX_HOME`, ...);
- a shared directory per program that the instances are reconciled into;
- MCP servers defined once and rendered into each agent's own format;
- structured edits (set, delete, migrate a value) applied to files the agent also writes.

## Usage

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-agents = {
      url = "github:conao3/nix-agents";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };
}
```

Import `inputs.nix-agents.homeManagerModules.default` into your home-manager configuration, then:

```nix
{ pkgs, agentsLib, ... }:
{
  programs.agents = {
    enable = true;
    instructions = ./AGENTS.md;

    types.claude = {
      package = pkgs.claude-code;
      envVar = "CLAUDE_CONFIG_DIR";
      homeDir = ".claude";
      instructionsFile = "CLAUDE.md";
      share = {
        enable = true;
        exclude = [ ".claude.json" ".claude.json.tmp" ".claude.json.*" ".credentials.json" ];
      };
      mcp = {
        format = "claude";
        key = "mcpServers";
        files = [ "settings.json" ".claude.json" ];
      };
      files."settings.json".settings = {
        theme = "dark";
        env.DISABLE_TELEMETRY = agentsLib.migrate { from = "1"; to = ""; };
      };
      files.".claude.json" = {
        scope = "instances";
        extraTargets = [ ".claude.json" ];
      };
    };

    instances = {
      "claude.personal" = { };
      "claude.work" = { };
    };

    mcpServers.docs.url = "https://example.com/mcp";
  };
}
```

This installs `claude.personal` and `claude.work`, each running `claude` with `CLAUDE_CONFIG_DIR=$HOME/.agents/.claude.<name>`. Both instances link their settings, projects and history into `~/.agents/.claude`, and `settings.json` and every `.claude.json` receive the `docs` server. [`examples/basic.nix`](examples/basic.nix) is a larger configuration covering Codex, cursor-agent, secrets, services and extra wrappers; `make check` builds it.

## Concepts

| Concept | Options | Result |
|---|---|---|
| Instance | `instances.<name>` (the type is the part of the name before the first `.`) | wrapper `<name>`, directory `<baseDir>/.<name>` |
| Program, executable and directory variable | `types.<t>.package` / `executable` / `envVar` | `makeWrapper ... --run 'export <envVar>="$HOME/<dir>"'` |
| Default configuration directory | `types.<t>.homeDir` | target of `config`-scoped files |
| Shared directory per program | `types.<t>.share.*`, `instances.<name>.share` | activation `agentsShare` |
| Directory shared by every agent | `common.*` | activation `agentsCommon` |
| Instructions | `instructions`, `types.<t>.instructionsFile`, `instances.<name>.instructions` | `home.file` symlinks |
| MCP servers | `mcpServers.<name>`, `types.<t>.mcp` | rendered for the `claude`, `codex` or `cursor` format and injected into `files` |
| Secrets | `mcpServers.<name>.bearerTokenEnvVar` / `bearerTokenFile` | an environment variable name or a file path, never the value |
| Structured edits | `types.<t>.files.<file>.settings` with `agentsLib.force` / `delete` / `migrate` | operation list in the store, applied by `agents-merge` |
| Merge strategy | `files.<file>.strategy` (`merge` / `overwrite` / `link`), `onConflict` | activation `agentsFiles` |
| Wrapper customization | `types.<t>.executable`, `instances.<name>.wrapper.makeWrapperArgs`, `extraWrappers` | `makeWrapper` |
| Aliases | `aliases.<exe>` | `exec <target> "$@"` |
| Long-running MCP servers | `mcpServers.<name>.service` | systemd user service `<name>-mcp` (Linux) |
| Shell shims | `zshFunctions.<name>` | zsh function appended to `initContent` |

## Options

Under `programs.agents`:

- `enable`
- `baseDir` (`.agents`)
- `instructions`
- `common.dir` (`<baseDir>/share`), `common.instructionsFile` (`AGENTS.md`), `common.directories`, `common.ensureFiles`
- `warningsFile` (`<baseDir>/settings-warnings.log`)
- `types.<t>`
  - `package`, `executable` (`lib.getExe package`), `envVar`, `homeDir`, `instructionsFile` (`AGENTS.md`)
  - `share.enable`, `share.dir` (`<baseDir>/.<t>`), `share.exclude`, `share.forceLinks`, `share.discard`, `share.history.file` (`history.jsonl`), `share.history.sortKey` (`.timestamp`), `share.keepFirst` (`*.sqlite*`)
  - `mcp.format` (`claude` / `codex` / `cursor`), `mcp.key`, `mcp.files`
  - `files.<file>.scope`, `extraTargets`, `format`, `strategy`, `source`, `settings`, `onConflict`
- `instances.<name>`
  - `type`, `dir` (`<baseDir>/.<name>`), `share`, `instructions`
  - `wrapper.enable`, `wrapper.makeWrapperArgs`
  - `extraWrappers.<exe>.executable`, `extraWrappers.<exe>.makeWrapperArgs`
- `aliases.<exe>`
- `mcpServers.<name>`
  - `url`, `command`, `args`, `env`, `headers`
  - `bearerTokenEnvVar`, `bearerTokenFile`
  - `enableFor` (every type with `mcp` set)
  - `service.description`, `service.execStart`
- `zshFunctions.<name>`

The `agentsLib` module argument provides `force`, `delete` and `migrate`.

## File targets

`types.<t>.files.<file>` names a file inside each target directory.

- `scope = "config"`: `homeDir` and the shared directory (when `share.enable`). Files in the shared directory are linked into every instance.
- `scope = "instances"`: every instance directory of the type, including instances outside the shared directory.
- `extraTargets`: further targets relative to the home directory, such as `~/.claude.json`.

`settings` may be a function of `{ dir }`, the absolute target directory built from `home.homeDirectory`.

Files listed in `types.<t>.mcp.files` receive the rendered servers at `mcp.key`, replacing what was there.

## Merge semantics

`settings` is flattened into one operation per leaf, written to the store with `builtins.toJSON`, and applied to the existing file by `agents-merge` with jq.

| Leaf | Operation |
|---|---|
| plain value, `onConflict = "warn"` | written when absent; left alone and reported when the file holds another value |
| plain value, `onConflict = "overwrite"` | always written |
| `agentsLib.force v` | the subtree is replaced by `v` |
| `agentsLib.delete` | the key is removed |
| `agentsLib.migrate { from; to; }` | `from` becomes `to`; any other value is left alone and reported |

Attribute sets recurse; lists and scalars are leaves. A missing or empty file starts from `{}`. A symlinked target starts from the content it points to and is replaced by a regular file; the link target is left untouched. The result is written to a fresh file from `mktemp` in the same directory and moved into place. TOML goes through yq and remarshal. A file that does not parse as JSON or TOML stops the activation.

Conflicts are written to `warningsFile` as `WARN: <type> settings: <file>: .<path>: expected <from> or <to>, got <current>, skipping`. The file is recreated on every activation.

`overwrite` copies a file generated with `pkgs.formats` on every activation. `link` places a read-only `home.file` symlink, for files the agent never writes.

## Shared directory reconciliation

For every type with `share.enable`, the directories of its sharing instances are visited in name order:

- Names in `share.exclude` stay in the instance. If one of them is a symlink into the shared directory, it is turned back into a regular file holding the linked content (or removed when the link is dangling).
- Symlinks are repointed at the shared directory.
- Directories move into the shared directory; when the shared copy exists, the instance's entries are added without overwriting.
- Regular files are first copied to `<shared dir>.backup-<timestamp>/`, then:
  - `share.history.file` is concatenated with the shared copy, deduplicated and sorted by `share.history.sortKey`;
  - files matching `share.keepFirst` keep whichever copy reached the shared directory first;
  - names in `share.discard` and the instructions file are dropped;
  - anything else keeps the newer copy.
- Finally `share.forceLinks`, the instructions file, the type's `config`-scoped files and everything in the shared directory that the instance lacks are linked into the instance.

## Activation order

1. `agentsDirs`: create `baseDir`, `common.dir`, the shared directories and every instance directory.
2. `agentsCommon`: `common.ensureFiles` and `common.directories`.
3. `agentsShare`: reconciliation.
4. `agentsFiles`: `merge` and `overwrite` files, after reconciliation so that files an instance rewrote are folded into the shared copy first.

Entries of your own can order themselves with `lib.hm.dag.entryAfter [ "agentsDirs" ]`.

## Evaluation checks

Evaluation fails when an instance names an unknown type, a sharing instance sets `instructions`, an MCP server sets both or neither of `url` and `command`, `enableFor` names a type without `mcp`, a server uses something its target format cannot express (`bearerTokenFile` for `codex` or `cursor`), or a `merge` file sets `source`.

## Limitations

- `service` creates systemd user services only.
- Activation writes files during a home-manager dry run.
- `zshFunctions` targets zsh only.
- Reconciliation and merging act on the top-level names of each directory.

## Origin

The module was written inside [conao3/nixos-configuration](https://github.com/conao3/nixos-configuration), where `home-manager/features/claude` had grown its own instance list, wrapper generation, jq patch scripts and reconciliation shell. It was rewritten as `home-manager/modules/agents` with the options above, the existing configuration was expressed through them, and the generated wrappers, files and activation results were compared against the previous ones on a sandboxed home directory and a real machine. It was then moved here unchanged, and nixos-configuration consumes it as the `nix-agents` flake input.

## Development

```sh
nix develop
make check   # nix flake check: builds examples/basic.nix and checks formatting
make fmt     # nix fmt
```

## License

Apache-2.0
