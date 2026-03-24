SHELL := /usr/bin/env bash
.RECIPEPREFIX := >

INVENTORY_HOST ?= 192.168.0.176
INVENTORY_USER ?= kali
INVENTORY_PORT ?= 22
INVENTORY_STRICT ?=
INVENTORY_IDENTITY ?=
INVENTORY_SSH_OPTS ?=

SCRIPTS := scripts/common.sh scripts/install_all.sh scripts/install_packages.sh scripts/install_dotfiles.sh scripts/install_pentest.sh scripts/inventory_remote_tools.sh scripts/inventory_manual_probe.sh scripts/inventory_system_facts_probe.sh scripts/inventory_report_generate.sh

.PHONY: validate inventory-remote

validate:
>@set -euo pipefail; \
>for script in $(SCRIPTS); do \
>  bash -n "$$script"; \
>done; \
>if command -v shellcheck >/dev/null 2>&1; then \
>  shellcheck -x $(SCRIPTS); \
>else \
>  echo "[INFO] shellcheck not found; skipping"; \
>fi

inventory-remote:
>@set -euo pipefail; \
>cmd=(./scripts/inventory_remote_tools.sh --host "$(INVENTORY_HOST)" --user "$(INVENTORY_USER)" --port "$(INVENTORY_PORT)"); \
>if [[ -n "$(INVENTORY_STRICT)" ]]; then cmd+=(--strict); fi; \
>if [[ -n "$(INVENTORY_IDENTITY)" ]]; then cmd+=(--identity "$(INVENTORY_IDENTITY)"); fi; \
>for opt in $(INVENTORY_SSH_OPTS); do cmd+=(--ssh-option "$$opt"); done; \
>"$${cmd[@]}"
