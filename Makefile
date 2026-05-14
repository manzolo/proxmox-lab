SHELL := /usr/bin/env bash

CLI := ./bin/proxmox-lab
CONFIG ?= ./config.env

.PHONY: help init status tui iso-latest iso-configured create start start-headless stop vm-inspect vm-serial network-up network-down clean clean-all autoinstall-scaffold autoinstall-validate lint

help:
	@printf '%s\n' \
		'Targets:' \
		'  make init                  create config and artifact directories' \
		'  make status                show lab status' \
		'  make tui                   open the interactive TUI' \
		'  make iso-latest            download latest Proxmox VE ISO' \
		'  make iso-configured        download PROXMOX_ISO_VERSION from config' \
		'  make create                create qcow2 disks' \
		'  make start                 start all VMs' \
		'  make start-headless        start all VMs without a GTK window' \
		'  make stop                  stop all VMs' \
		'  make vm-inspect            inspect current VM pid/log paths' \
		'  make vm-serial             print the latest headless serial log for VM1' \
		'  make network-up            bring TAP bridge up (root)' \
		'  make network-down          tear TAP bridge down (root)' \
		'  make clean                 remove disk artifacts' \
		'  make clean-all             remove logs, pid files, disks' \
		'  make autoinstall-scaffold  create artifacts/autoinstall/answer.toml' \
		'  make autoinstall-validate  validate artifacts/autoinstall/answer.toml' \
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

start:
	$(CLI) --config $(CONFIG) vm start

start-headless:
	$(CLI) --config $(CONFIG) vm start-headless

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

lint:
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck $(CLI) create.sh run.sh destroy.sh tap/create.sh tap/run.sh tap/destroy.sh; \
	else \
		printf 'shellcheck not installed\n'; \
	fi
