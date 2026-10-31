# AGENTS.md

`nix-agents` is a home-manager module (`programs.agents`) for running coding agents as several instances. The module is the set of files at the repository root: `default.nix` (config), `options.nix`, `lib.nix` (`agentsLib` and the flattening of settings), `mcp.nix` (renderers per MCP format), `share.nix` (reconciliation script) and `merge.jq`.

## Conventions

- Commit messages, comments and documentation are in English.
- Options are documented in `options.nix` and summarized in `README.md`; change both together.
- JSON handed to activation scripts is generated with `builtins.toJSON` into store files, never interpolated into shell strings.
- Behaviour that only one agent needs belongs in the consumer's configuration through `executable`, `makeWrapperArgs`, `extraWrappers`, `settings` functions or its own `home.activation` entries.

## Verification

Run `make check` inside `nix develop`. It runs `nix flake check`, which evaluates `examples/minimal.nix`, `practical.nix`, `supported-agents.nix` and `extras.nix` with a minimal home-manager configuration, builds the activation package of `examples/basic.nix`, checks that `README.md` contains each evaluated example verbatim, and checks formatting.

- When an example changes, paste the new file into the matching code block of `README.md`; the `readme-examples` check fails until they match.
- The configuration examples in `README.md` are those files; a new one becomes a file in `examples/` with its own `evalExample` check. The installation snippets (the consumer `flake.nix` and the NixOS / nix-darwin import) are checked by evaluating a scratch consumer flake with `--override-input nix-agents path:.`.
- Extend `examples/basic.nix` when adding an option.
