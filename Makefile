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
        links unlink salt-call apply highstate overstate-deploy overstate-apply \
        overstate-checkout

# ------------------------------------------------------------------------------
# Help
# ------------------------------------------------------------------------------
help:
	@echo "suse-baseline-salt Makefile"
	@echo
	@echo "Testing:"
	@echo "  lint                Run yamllint over the repository"
	@echo "  goss                Run all Goss tests (requires goss + target system state)"
	@echo "  goss-<name>         Run specific Goss test, e.g. make goss-timesyncd, make goss-baseline"
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
	@echo
	@echo "Overstate deployment (master file/pillar roots):"
	@echo "  overstate-checkout  Clone (or fast-forward) this repo at the roots"
	@echo "                      so the checkout satisfies the Sync now"
	@echo "                      contract: tracking branch, clean tree,"
	@echo "                      world-readable bits for the master workers."
	@echo "                      (defaults OVERSTATE_SRV=/var/lib/overstate/srv,"
	@echo "                      OVERSTATE_REPO=<this repo's origin>,"
	@echo "                      OVERSTATE_BRANCH=main; uses sudo only when"
	@echo "                      the target is not writable)"
	@echo "                      Override for other layouts, e.g.:"
	@echo "                        make overstate-checkout OVERSTATE_SRV=/path/to/salt-srv"
	@echo "  overstate-deploy    Legacy plain-copy deploy (subset of trees,"
	@echo "                      generated top files). Copies are NOT git"
	@echo "                      checkouts, so Sync now stays dark on them."
	@echo "  overstate-apply     Alias for overstate-deploy."
	@echo "  overstate-apply     Alias for overstate-deploy."

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

# ------------------------------------------------------------------------------
# Overstate deployment (master file/pillar roots)
# ------------------------------------------------------------------------------
# Overstate serves states from <srv>/salt and pillar from <srv>/pillar, where
# <srv> is /var/lib/overstate/srv on prod. That host dir is bind-mounted
# READ-ONLY into the cdalvaro-layout master container at
# /home/salt/data/srv (the master's file_roots/pillar_roots), so:
#  - plain copies are used deliberately, never symlinks: a link pointing
#    outside the bind mount dangles inside the container;
#  - deployed trees are opened to a+rX below: a root umask of 027 lands
#    files as 640/750, which the (non-root) master workers cannot
#    traverse — fileserver.file_list then silently omits the whole tree
#    and applies fail with "No matching sls found".
OVERSTATE_SRV ?= /var/lib/overstate/srv
OVERSTATE_SALT ?= $(OVERSTATE_SRV)/salt
OVERSTATE_PILLAR ?= $(OVERSTATE_SRV)/pillar
OVERSTATE_MASTER ?= salt-master
# Source for overstate-checkout. Defaults to this checkout's own origin so
# the deployed tree is literally this repo at the chosen branch.
OVERSTATE_REPO ?= $(shell git config --get remote.origin.url 2>/dev/null)
OVERSTATE_BRANCH ?= main
# Optional owner for the deployed checkout (user or UID). Empty keeps the
# current owner, except under sudo, where the invoking user takes over so a
# rootless app container can still pull. The checkout must be writable by
# whatever user the app container runs as, or Sync now fails closed; a
# different owner there also trips git's dubious-ownership guard, which only
# matching ownership fixes.
OVERSTATE_OWNER ?=

overstate-deploy:
	@if [ -z "$(OVERSTATE_SRV)" ]; then \
		echo "error: OVERSTATE_SRV is empty" >&2; exit 1; \
	fi
	@if { [ -e "$(OVERSTATE_SRV)" ] && [ ! -w "$(OVERSTATE_SRV)" ]; } || \
	   { [ ! -e "$(OVERSTATE_SRV)" ] && [ ! -w "$(dir $(OVERSTATE_SRV))" ]; }; then \
		echo "==> Elevating with sudo to write $(OVERSTATE_SRV)..."; \
		sudo $(MAKE) --no-print-directory overstate-deploy OVERSTATE_SRV="$(OVERSTATE_SRV)"; \
		exit $$?; \
	fi
	@echo "==> Deploying baseline into Overstate roots: $(OVERSTATE_SRV)"
	@mkdir -p $(OVERSTATE_SALT) $(OVERSTATE_PILLAR) $(OVERSTATE_SALT)/_modules
	@rm -rf $(OVERSTATE_SALT)/baseline
	@cp -r $(REPO_ROOT)/salt/baseline $(OVERSTATE_SALT)/baseline
	@cp -f $(REPO_ROOT)/salt/_modules/*.py $(OVERSTATE_SALT)/_modules/
	@cp -f $(REPO_ROOT)/pillar/baseline.sls $(OVERSTATE_PILLAR)/baseline.sls
	@chmod -R a+rX $(OVERSTATE_SALT)/baseline $(OVERSTATE_SALT)/_modules $(OVERSTATE_PILLAR)
	@if [ ! -f $(OVERSTATE_PILLAR)/top.sls ]; then \
		cp $(REPO_ROOT)/pillar/top.sls $(OVERSTATE_PILLAR)/top.sls; \
		echo "    installed pillar top.sls"; \
	elif ! grep -qE '^[[:space:]]*-[[:space:]]*baseline[[:space:]]*$$' $(OVERSTATE_PILLAR)/top.sls; then \
		echo "    NOTE: $(OVERSTATE_PILLAR)/top.sls exists without a baseline entry:"; \
		echo "          add '- baseline' under base '*' to serve pillar."; \
	fi
	@if [ ! -f $(OVERSTATE_SALT)/top.sls ]; then \
		printf "base:\n  '*':\n    - baseline\n" > $(OVERSTATE_SALT)/top.sls; \
		echo "    created salt top.sls with baseline"; \
	elif ! grep -qE '^[[:space:]]*-[[:space:]]*baseline[[:space:]]*$$' $(OVERSTATE_SALT)/top.sls; then \
		echo "    NOTE: $(OVERSTATE_SALT)/top.sls exists without a baseline entry:"; \
		echo "          add '- baseline' under base '*' (nightly highstate needs it)."; \
	fi
	@echo "Deployed. Verify the master serves the tree, then apply:"
	@echo "  podman exec $(OVERSTATE_MASTER) salt-run fileserver.update"
	@echo "  podman exec $(OVERSTATE_MASTER) salt-run fileserver.file_list saltenv=base | grep -c baseline"
	@echo "  # nonzero count -> apply from Overstate Jobs: state.apply baseline (or highstate)."
	@echo "  # zero count -> the container does not see $(OVERSTATE_SRV): check its bind mounts"
	@echo "  # and the master's file_roots before re-running this target."

overstate-apply: overstate-deploy

# ------------------------------------------------------------------------------
# Overstate checkout (Sync now compatible)
# ------------------------------------------------------------------------------
# overstate-deploy copies files; copies are not git checkouts, so Overstate's
# Sync now button (git fetch + pull --ff-only on FILE_ROOTS) refuses them.
# This target instead places a real tracking checkout at OVERSTATE_SRV, which
# is exactly the layout Overstate documents: the app reads
# <srv>/salt (FILE_ROOTS) and Sync now fast-forwards the whole checkout,
# while the master serves <srv>/salt + <srv>/pillar read-only.
#
# Fail-closed throughout: an existing checkout is only ever fast-forwarded;
# diverged branches and dirty trees refuse with the git reason. A non-empty
# directory that is NOT a checkout is never touched — move it aside first
# (and diff it: local-only pillar secrets live outside git by design).
overstate-checkout:
	@if [ -z "$(OVERSTATE_SRV)" ]; then \
		echo "error: OVERSTATE_SRV is empty" >&2; exit 1; \
	fi
	@if [ -z "$(OVERSTATE_REPO)" ]; then \
		echo "error: OVERSTATE_REPO is empty (no origin on this checkout?)" >&2; exit 1; \
	fi
	@if { [ -e "$(OVERSTATE_SRV)" ] && [ ! -w "$(OVERSTATE_SRV)" ]; } || \
	   { [ ! -e "$(OVERSTATE_SRV)" ] && [ ! -w "$(dir $(OVERSTATE_SRV))" ]; }; then \
		echo "==> Elevating with sudo to write $(OVERSTATE_SRV)..."; \
		sudo $(MAKE) --no-print-directory overstate-checkout \
			OVERSTATE_SRV="$(OVERSTATE_SRV)" OVERSTATE_REPO="$(OVERSTATE_REPO)" \
			OVERSTATE_BRANCH="$(OVERSTATE_BRANCH)" OVERSTATE_OWNER="$(OVERSTATE_OWNER)"; \
		exit $$?; \
	fi
	@echo "==> Overstate checkout at $(OVERSTATE_SRV) from $(OVERSTATE_REPO) [$(OVERSTATE_BRANCH)]"
	@if [ -d "$(OVERSTATE_SRV)/.git" ]; then \
		echo "    existing checkout: fetching + fast-forwarding only"; \
		git -C "$(OVERSTATE_SRV)" fetch --prune origin; \
		cur=$$(git -C "$(OVERSTATE_SRV)" symbolic-ref --quiet --short HEAD || echo detached); \
		if [ "$$cur" != "$(OVERSTATE_BRANCH)" ]; then \
			if git -C "$(OVERSTATE_SRV)" show-ref --quiet --verify "refs/heads/$(OVERSTATE_BRANCH)"; then \
				git -C "$(OVERSTATE_SRV)" checkout "$(OVERSTATE_BRANCH)"; \
			else \
				git -C "$(OVERSTATE_SRV)" checkout -b "$(OVERSTATE_BRANCH)" --track "origin/$(OVERSTATE_BRANCH)"; \
			fi; \
		fi; \
		git -C "$(OVERSTATE_SRV)" pull --ff-only; \
	else \
		if [ -e "$(OVERSTATE_SRV)" ] && [ -n "$$(ls -A "$(OVERSTATE_SRV)")" ]; then \
			echo "error: $(OVERSTATE_SRV) exists, is not a git checkout, and is not empty." >&2; \
			echo "Refusing to touch it: move it aside first, diffing for local-only" >&2; \
			echo "files (pillar secrets) before you do." >&2; \
			exit 1; \
		fi; \
		mkdir -p "$(OVERSTATE_SRV)"; \
		git clone --branch "$(OVERSTATE_BRANCH)" -- "$(OVERSTATE_REPO)" "$(OVERSTATE_SRV)"; \
	fi
# Ownership first (pulls run as the app user), then world-readable bits so
# the non-root master workers traverse the bind mount — same a+rX rule as
# the copy path: a root umask of 027 otherwise hides the tree again.
	@owner="$(OVERSTATE_OWNER)"; \
	if [ -z "$$owner" ] && [ -n "$$SUDO_USER" ] && [ "$$SUDO_USER" != "root" ]; then \
		owner="$$SUDO_USER"; \
	fi; \
	if [ -n "$$owner" ]; then \
		chown -R "$$owner" "$(OVERSTATE_SRV)"; \
		echo "    owner: $$owner"; \
	fi
	@chmod -R a+rX "$(OVERSTATE_SRV)"
	@echo "    checkout: $$(git -C "$(OVERSTATE_SRV)" rev-parse --short HEAD) tracking $$(git -C "$(OVERSTATE_SRV)" rev-parse --abbrev-ref --symbolic-full-name "@{u}")"
	@dirty=$$(git -C "$(OVERSTATE_SRV)" status --porcelain | wc -l); \
	if [ "$$dirty" != "0" ]; then \
		echo "    WARNING: $$dirty dirty file(s); Sync now refuses until clean." >&2; \
	fi
	@if [ ! -f "$(OVERSTATE_SRV)/salt/top.sls" ]; then \
		echo "    WARNING: no salt/top.sls — the master serves nothing without it." >&2; \
	fi
	@if [ ! -f "$(OVERSTATE_SRV)/pillar/top.sls" ]; then \
		echo "    WARNING: no pillar/top.sls." >&2; \
	fi
	@echo "Checkout ready. Verify the master serves the tree, then apply:"
	@echo "  podman exec $(OVERSTATE_MASTER) salt-run fileserver.update"
	@echo "  podman exec $(OVERSTATE_MASTER) salt-run fileserver.file_list saltenv=base | grep -c baseline"
	@echo "  # nonzero count -> apply from Overstate Jobs: state.apply baseline (or highstate)."
	@echo "  # zero count -> the container does not see $(OVERSTATE_SRV): check its bind mounts"
	@echo "  # and the master's file_roots before re-running this target."
	@echo "  # Afterwards, Overstate Files -> Sync now fast-forwards this checkout."
