SHELL := /usr/bin/env bash

CLI := ./bin/proxmox-lab
CONFIG ?= ./config.env

.PHONY: help init status tui iso-latest iso-configured create install-headless boot boot-headless start start-headless stop vm-inspect vm-serial network-up network-down clean clean-all autoinstall-scaffold autoinstall-validate autoinstall-prepare cluster-scaffold lint

help:
	@printf '%s\n' \
		'Targets:' \
		'  make init                  create config and artifact directories' \
		'  make status                show lab status' \
		'  make tui                   open the interactive TUI' \
		'  make iso-latest            download latest Proxmox VE ISO' \
		'  make iso-configured        download PROXMOX_ISO_VERSION from config' \
		'  make create                create qcow2 disks' \
		'  make install-headless      unattended install for all VMs, exit on reboot' \
		'  make boot                  boot all VMs from disk' \
		'  make boot-headless         boot all VMs from disk without a GTK window' \
		'  make start                 alias for make boot' \
		'  make start-headless        alias for make boot-headless' \
		'  make stop                  stop all VMs' \
		'  make vm-inspect            inspect current VM pid/log paths' \
		'  make vm-serial             print the latest headless serial log for VM1' \
		'  make network-up            bring TAP bridge up (root)' \
		'  make network-down          tear TAP bridge down (root)' \
		'  make clean                 remove disk artifacts' \
		'  make clean-all             remove logs, pid files, disks' \
		'  make autoinstall-scaffold  create per-node answer files under artifacts/autoinstall/' \
		'  make autoinstall-validate  validate all per-node answer files' \
		'  make autoinstall-prepare   build per-node unattended ISOs from current base ISO' \
		'  make cluster-scaffold      generate cluster+data-pool bootstrap scripts' \
		'  make lint                  run shellcheck when available'

init:
	$(CLI) --config $(CONFIG) init

status:
	$(CLI) --config $(CONFIG) status

tui:
	$(CLI) --config $(CONFIG) tui

iso-latest:
	$(CLI) --config $(CONFIG) iso fetch latest

iso-configured:
	$(CLI) --config $(CONFIG) iso fetch configured

create:
	$(CLI) --config $(CONFIG) vm create

install-headless:
	$(CLI) --config $(CONFIG) vm install-headless

boot:
	$(CLI) --config $(CONFIG) vm boot

boot-headless:
	$(CLI) --config $(CONFIG) vm boot-headless

start:
	$(CLI) --config $(CONFIG) vm boot

start-headless:
	$(CLI) --config $(CONFIG) vm boot-headless

stop:
	$(CLI) --config $(CONFIG) vm stop

vm-inspect:
	$(CLI) --config $(CONFIG) vm inspect

vm-serial:
	$(CLI) --config $(CONFIG) vm serial 1

network-up:
	$(CLI) --config $(CONFIG) --set USE_TAP_NETWORK=1 network up

network-down:
	$(CLI) --config $(CONFIG) --set USE_TAP_NETWORK=1 network down

clean:
	$(CLI) --config $(CONFIG) clean disks

clean-all:
	$(CLI) --config $(CONFIG) clean all

autoinstall-scaffold:
	$(CLI) --config $(CONFIG) autoinstall scaffold

autoinstall-validate:
	$(CLI) --config $(CONFIG) autoinstall validate

autoinstall-prepare:
	$(CLI) --config $(CONFIG) autoinstall prepare-iso "$$($(CLI) --config $(CONFIG) iso configured-path)"

cluster-scaffold:
	$(CLI) --config $(CONFIG) cluster scaffold

lint:
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck $(CLI) create.sh run.sh destroy.sh tap/create.sh tap/run.sh tap/destroy.sh; \
	else \
		printf 'shellcheck not installed\n'; \
	fi
