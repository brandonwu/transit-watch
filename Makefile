SHELL := /bin/bash
SDK_CFG := $(HOME)/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg
SDK ?= $(patsubst %/,%,$(shell cat "$(SDK_CFG)" 2>/dev/null))
DEVICE ?= instinct2x
APP := bin/MuniMetro.prg
TEST_APP := bin/MuniMetroTests.prg
APP_STEM := $(basename $(notdir $(APP)))
SETTINGS_JSON := $(patsubst %.prg,%-settings.json,$(APP))
SIM_SETTINGS := 0:/GARMIN/Settings/$(shell printf '%s' '$(APP_STEM)' | tr '[:lower:]' '[:upper:]')-settings.json
SIMULATOR_HOST ?= 127.0.0.1
SIMULATOR_PORT ?= 1234
KEY := developer_key.der
MONKEYC := $(SDK)/bin/monkeyc
MONKEYDO := $(SDK)/bin/monkeydo
CONNECTIQ := $(SDK)/bin/connectiq
CIQ_SHELL := $(SDK)/bin/shell
STOP_DATA := source/StopData.mc

.PHONY: all build clean key sim run settings-check settings-install test test-build check-sdk stops

all: build

check-sdk:
	@test -x "$(MONKEYC)" || { echo "Connect IQ SDK not found. Install it with Garmin SDK Manager or set SDK=/path/to/sdk."; exit 1; }

key:
	@test -f "$(KEY)" || { \
		openssl genrsa -out developer_key.pem 4096 >/dev/null 2>&1; \
		openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out "$(KEY)" -nocrypt; \
	}

# Refresh the embedded stop table from the 511.org feed. The cached feed
# in data/ is reused when present; delete it to pull a new copy.
stops:
	python3 tools/fetch_stops.py

build: check-sdk key
	@mkdir -p bin
	"$(MONKEYC)" -f monkey.jungle -d "$(DEVICE)" -y "$(KEY)" -o "$(APP)" -O 2 -w

test-build: check-sdk key
	@mkdir -p bin
	"$(MONKEYC)" -f monkey.jungle -d "$(DEVICE)" -y "$(KEY)" -o "$(TEST_APP)" -O 2 -w -t

sim: check-sdk
	@"$(CONNECTIQ)"
	@sleep 2
	@echo "Connect IQ simulator started."

settings-check: build
	@test -s "$(SETTINGS_JSON)" || { \
		echo "Missing generated settings file: $(SETTINGS_JSON)"; \
		echo "Check the <settings> resources and compiler output."; \
		exit 1; \
	}

settings-install: settings-check
	"$(CIQ_SHELL)" --transport=tcp --transport_args="$(SIMULATOR_HOST):$(SIMULATOR_PORT)" push "$(SETTINGS_JSON)" "$(SIM_SETTINGS)"

run: settings-install
	"$(MONKEYDO)" "$(APP)" "$(DEVICE)"

test: test-build
	@output=$$(mktemp); \
	trap 'rm -f "$$output"' EXIT; \
	"$(MONKEYDO)" "$(TEST_APP)" "$(DEVICE)" -t 2>&1 | tee "$$output"; \
	status=$${PIPESTATUS[0]}; \
	if grep -Eq '^PASSED \(passed=[0-9]+, failed=0, errors=0\)$$' "$$output"; then exit 0; fi; \
	exit $$status

clean:
	rm -rf bin
