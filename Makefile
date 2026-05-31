# Makefile for manual testing of suse-baseline-salt on a SUSE VM
#
# Usage examples:
#   make lint
#   make goss
#   make goss-sysctl
#   make goss-firewalld
#   make install-goss

GOSS_VERSION ?= v0.4.9
GOSS_URL := https://github.com/goss-org/goss/releases/download/$(GOSS_VERSION)/goss-linux-amd64
GOSS := $(shell command -v goss 2>/dev/null || echo ./goss)

.PHONY: help lint goss install-goss clean

help:
	@echo "suse-baseline-salt testing targets:"
	@echo ""
	@echo "  make lint            - Run yamllint on all YAML files"
	@echo "  make goss            - Run all Goss tests"
	@echo "  make goss-<name>     - Run Goss tests for a specific component (e.g. make goss-sysctl)"
	@echo "  make install-goss    - Download goss binary to current directory"
	@echo "  make clean           - Remove downloaded goss binary"
	@echo ""

lint:
	yamllint .

goss: goss-binary
	$(GOSS) --gossfile goss/goss.yaml validate

goss-%: goss-binary
	$(GOSS) --gossfile goss/$*.yaml validate

install-goss:
	@if [ -z "$(shell command -v goss)" ]; then \
		echo "Downloading goss $(GOSS_VERSION)..."; \
		curl -fsSL $(GOSS_URL) -o goss && chmod +x goss; \
		echo "Installed ./goss"; \
	else \
		echo "goss is already installed at $$(command -v goss)"; \
	fi

clean:
	rm -f goss

goss-binary:
	@$(MAKE) --no-print-directory install-goss > /dev/null 2>&1 || true
	@if [ ! -x "$(GOSS)" ]; then \
		echo "goss binary not found. Run 'make install-goss' first."; \
		exit 1; \
	fi
