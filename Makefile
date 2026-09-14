# suse-baseline-salt
# Makefile for development, testing, and local Salt execution.

REPO_ROOT := $(CURDIR)

# ------------------------------------------------------------------------------
# Goss (testing) configuration
# ------------------------------------------------------------------------------
GOSS_VERSION ?= v0.4.9
# Local fallback lives under bin/ (NOT ./goss: goss/ is the test directory).
GOSS_BIN ?= $(REPO_ROOT)/bin/goss
GOSS_OS := $(shell uname -s | tr '[:upper:]' '[:lower:]')
GOSS_ARCH := $(shell uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/')
GOSS_URL := https://github.com/goss-org/goss/releases/download/$(GOSS_VERSION)/goss-$(GOSS_OS)-$(GOSS_ARCH)
GOSS := $(shell command -v goss 2>/dev/null || echo $(GOSS_BIN))

# ------------------------------------------------------------------------------
# Salt configuration for local / masterless usage
# ------------------------------------------------------------------------------
SALT_CALL  ?= salt-call
SALT_SRV   ?= /srv/salt
PILLAR_SRV ?= /srv/pillar

# ------------------------------------------------------------------------------
# Phony targets
# ------------------------------------------------------------------------------
.PHONY: help lint goss install-goss clean \
        links unlink salt-call apply highstate

# ------------------------------------------------------------------------------
# Help
# ------------------------------------------------------------------------------
help:
	@echo "suse-baseline-salt Makefile"
	@echo
	@echo "Testing:"
	@echo "  lint                Run yamllint over the repository"
	@echo "  goss                Run all Goss tests (requires goss + target system state)"
	@echo "  goss-<name>         Run specific Goss test, e.g. make goss-chrony, make goss-baseline"
	@echo "  install-goss        Download a local goss binary to ./bin/goss"
	@echo "  clean               Remove local goss binary"
	@echo
	@echo "Salt development (run on the target machine or test VM):"
	@echo "  links               Install symlinks: /srv/salt -> repo/salt and /srv/pillar -> repo/pillar"
	@echo "                      (uses sudo automatically if not already root)"
	@echo "  unlink              Remove the /srv symlinks"
	@echo
	@echo "  salt-call           Run salt-call locally using this repository directly."
	@echo "                      Usage:"
	@echo "                        sudo make salt-call SALT_ARGS='state.apply baseline'"
	@echo "                        sudo make salt-call SALT_ARGS='state.apply baseline test=True'"
	@echo
	@echo "                      This does NOT require the /srv symlinks (it uses --file-root / --pillar-root)."
	@echo
	@echo "  apply               Shortcut for 'state.apply baseline' (or MODULE=...)"
	@echo "                      Examples:"
	@echo "                        sudo make apply"
	@echo "                        sudo make apply MODULE=baseline test=True"
	@echo
	@echo "  highstate           Run state.highstate using the local repo tree."

# ------------------------------------------------------------------------------
# Testing targets (existing)
# ------------------------------------------------------------------------------
lint:
	yamllint .

goss: goss-binary
	$(GOSS) --gossfile goss/goss.yaml validate

goss-%: goss-binary
	$(GOSS) --gossfile goss/$*.yaml validate

install-goss:
	@if [ -z "$(shell command -v goss)" ]; then \
		echo "Downloading goss $(GOSS_VERSION)..."; \
		mkdir -p $(REPO_ROOT)/bin; \
		curl -fsSL $(GOSS_URL) -o $(GOSS_BIN) && chmod +x $(GOSS_BIN); \
		echo "Installed $(GOSS_BIN)"; \
	else \
		echo "goss is already installed at $$(command -v goss)"; \
	fi

clean:
	rm -f $(GOSS_BIN)

goss-binary:
	@$(MAKE) --no-print-directory install-goss > /dev/null 2>&1 || true
	@if [ ! -x "$(GOSS)" ]; then \
		echo "goss binary not found. Run 'make install-goss' first."; \
		exit 1; \
	fi

# ------------------------------------------------------------------------------
# Salt symlinks (for traditional /srv layout and masterless minions)
# ------------------------------------------------------------------------------
links:
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "==> Elevating with sudo to create /srv symlinks..."; \
		sudo $(MAKE) --no-print-directory links; \
		exit $$?; \
	fi
	@echo "==> Creating Salt symlinks"
	@mkdir -p $(dir $(SALT_SRV)) $(dir $(PILLAR_SRV))
# Drop stale nested links from older layouts, then link the trees themselves.
# -T (GNU ln, available on the SUSE target) treats the destination as a plain
# file so an existing /srv/salt directory can never silently become /srv/salt/salt.
	@rm -f $(SALT_SRV)/salt $(SALT_SRV)/baseline $(SALT_SRV)/top.sls
	@rm -f $(PILLAR_SRV)/pillar $(PILLAR_SRV)/top.sls
	@rmdir $(SALT_SRV) $(PILLAR_SRV) 2>/dev/null || true
	@ln -sfnT $(REPO_ROOT)/salt $(SALT_SRV)
	@ln -sfnT $(REPO_ROOT)/pillar $(PILLAR_SRV)
	@echo "    $(SALT_SRV) -> $(REPO_ROOT)/salt"
	@echo "    $(PILLAR_SRV) -> $(REPO_ROOT)/pillar"
	@echo "Symlinks installed. Your Salt minion will now see the repo contents under /srv."
	@echo "You can run: salt-call --local state.apply baseline   (or use 'make salt-call')"

unlink:
	@if [ "$$(id -u)" -ne 0 ]; then \
		sudo $(MAKE) --no-print-directory unlink; \
		exit $$?; \
	fi
	@echo "==> Removing Salt symlinks"
	@rm -f $(SALT_SRV)
	@rm -f $(PILLAR_SRV)
	@echo "Symlinks removed."

# ------------------------------------------------------------------------------
# Local salt-call execution (masterless, no reliance on /srv or /etc/salt/minion)
# ------------------------------------------------------------------------------
salt-call:
	@cmd="$(SALT_CALL) --local --file-root=$(REPO_ROOT)/salt --pillar-root=$(REPO_ROOT)/pillar $(SALT_ARGS)"; \
	if [ "$$(id -u)" -ne 0 ]; then \
		cmd="sudo $$cmd"; \
	fi; \
	echo "==> $$cmd"; \
	eval $$cmd

# Convenience wrappers around salt-call
apply:
	@$(MAKE) --no-print-directory salt-call SALT_ARGS="state.apply $(or $(MODULE),baseline) $(SALT_ARGS)"

highstate:
	@$(MAKE) --no-print-directory salt-call SALT_ARGS="state.highstate $(SALT_ARGS)"
