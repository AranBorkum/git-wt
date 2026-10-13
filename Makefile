SHELL := /usr/bin/env bash

PREFIX ?= $(HOME)/.local
BINDIR := $(PREFIX)/bin
LIBDIR := $(PREFIX)/lib/git-wt

SHELL_FILES := git-wt $(wildcard lib/*.sh) $(wildcard tests/*.sh)

.DEFAULT_GOAL := check

.PHONY: check
check: lint fmt-check test ## Run lint, format check and tests

.PHONY: test
test: ## Run the test suite
	@bash tests/run.sh

.PHONY: lint
lint: ## Run shellcheck over all shell files
	@shellcheck --severity=style --external-sources $(SHELL_FILES)

.PHONY: fmt
fmt: ## Format all shell files in place
	@shfmt --write --language-dialect bash --indent 0 --case-indent $(SHELL_FILES)

.PHONY: fmt-check
fmt-check: ## Verify formatting without writing
	@shfmt --diff --language-dialect bash --indent 0 --case-indent $(SHELL_FILES)

.PHONY: install
install: ## Install git-wt into $(PREFIX)
	@install -d "$(BINDIR)" "$(LIBDIR)"
	@install -m 0755 git-wt "$(BINDIR)/git-wt"
	@install -m 0644 lib/*.sh "$(LIBDIR)/"
	@printf 'Installed git-wt to %s\n' "$(BINDIR)/git-wt"
	@printf 'Ensure %s is on your PATH, then use: git wt --help\n' "$(BINDIR)"

.PHONY: uninstall
uninstall: ## Remove an installed git-wt
	@rm -f "$(BINDIR)/git-wt"
	@rm -rf "$(LIBDIR)"
	@printf 'Removed git-wt from %s\n' "$(BINDIR)"

.PHONY: version
version: ## Print the current version
	@./git-wt version

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk -F':.*?## ' '{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'
