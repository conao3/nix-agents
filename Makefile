.PHONY: check fmt

check:
	nix flake check --print-build-logs

fmt:
	nix fmt
