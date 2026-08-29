# ==============================================================================
# Media Browser App - Makefile
# ==============================================================================

SHELL := /bin/bash
APP_NAME := Media Browser
APP_BUNDLE := build/macos/Build/Products/Release/$(APP_NAME).app
INSTALL_DIR := /Applications

.PHONY: default help run run-macos run-linux run-windows build build-macos build-linux build-windows install uninstall test analyze lint clean get upgrade check

# Default target
default: help

## 📖 Help
help:
	@echo ""
	@echo "Media Browser Development & Build Commands:"
	@echo ""
	@echo "  Development:"
	@echo "    make run           - Run app on macOS in debug mode (default)"
	@echo "    make run-macos     - Run app on macOS"
	@echo "    make run-linux     - Run app on Linux"
	@echo "    make run-windows   - Run app on Windows"
	@echo ""
	@echo "  Building:"
	@echo "    make build         - Build macOS release app bundle"
	@echo "    make build-macos   - Build macOS release app bundle"
	@echo "    make build-linux   - Build Linux release bundle"
	@echo "    make build-windows - Build Windows release bundle"
	@echo ""
	@echo "  Installation:"
	@echo "    make install       - Install built macOS app to $(INSTALL_DIR)/$(APP_NAME).app"
	@echo "    make uninstall     - Remove app from $(INSTALL_DIR)/$(APP_NAME).app"
	@echo ""
	@echo "  Quality & Maintenance:"
	@echo "    make test          - Run all Flutter unit and widget tests"
	@echo "    make analyze       - Run Dart analyzer for static checks"
	@echo "    make check         - Run analyzer and all tests"
	@echo "    make clean         - Clean Flutter build cache and artifacts"
	@echo "    make get           - Fetch Flutter package dependencies"
	@echo "    make upgrade       - Upgrade Flutter package dependencies"
	@echo ""

## 🚀 Run
run: run-macos

run-macos:
	flutter run -d macos

run-linux:
	flutter run -d linux

run-windows:
	flutter run -d windows

## 📦 Build
build: build-macos

build-macos:
	flutter build macos --release

build-linux:
	flutter build linux --release

build-windows:
	flutter build windows --release

## 💾 Install / Uninstall (macOS)
install:
	@if [ ! -d "$(APP_BUNDLE)" ]; then \
		echo "App bundle not found at '$(APP_BUNDLE)'. Building release first..."; \
		$(MAKE) build-macos; \
	fi
	@echo "Installing '$(APP_NAME).app' to $(INSTALL_DIR)..."
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	cp -R "$(APP_BUNDLE)" "$(INSTALL_DIR)/"
	@echo "✅ Successfully installed $(APP_NAME) to $(INSTALL_DIR)/$(APP_NAME).app"

uninstall:
	@if [ -d "$(INSTALL_DIR)/$(APP_NAME).app" ]; then \
		rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"; \
		echo "✅ Removed $(INSTALL_DIR)/$(APP_NAME).app"; \
	else \
		echo "App not found in $(INSTALL_DIR)"; \
	fi

## 🧪 Quality Gates
test:
	flutter test

analyze:
	flutter analyze

lint: analyze

check: analyze test

## 🧹 Maintenance
clean:
	flutter clean

get:
	flutter pub get

upgrade:
	flutter pub upgrade
