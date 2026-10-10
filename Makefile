APP := build/Agent Consumption.app
SWIFT_SOURCES := Sources Tests Package.swift

.PHONY: help bootstrap hooks test coverage check lint format security build app run install logs ci clean

help:            ## List targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*## /\t/'

bootstrap:       ## Install dev tools (Homebrew) and git hooks
	brew install swiftlint zizmor gitleaks actionlint shellcheck
	$(MAKE) hooks

hooks:           ## Use .githooks (pre-commit: fast checks, pre-push: full gate)
	git config core.hooksPath .githooks

test:            ## Package tests (Swift Testing)
	swift test

coverage:        ## Tests plus the coverage floors
	python3 scripts/check-coverage.py

check:           ## Harness checks: architecture, docs, file size
	python3 scripts/check-architecture.py
	python3 scripts/check-docs.py
	bash scripts/check-file-size.sh

lint:            ## swift-format (strict) and SwiftLint (strict)
	swift format lint --strict --recursive $(SWIFT_SOURCES) --configuration .swift-format
	swiftlint lint --strict --quiet

format:          ## Apply swift-format and SwiftLint autofixes
	swift format format --in-place --recursive $(SWIFT_SOURCES) --configuration .swift-format
	swiftlint --fix --quiet

security:        ## Workflow audit (zizmor), actionlint, shellcheck, secret scan
	zizmor --pedantic .github
	actionlint
	shellcheck scripts/*.sh .githooks/*
	gitleaks git --no-banner --redact --verbose

build:           ## Debug build, warnings are errors
	swift build -Xswiftc -warnings-as-errors

app:             ## Release .app bundle in build/
	bash scripts/bundle.sh

run: app         ## Build and launch the menu bar app
	-pkill -x AgentConsumption
	open "$(APP)"

install: app     ## Copy to /Applications
	-pkill -x AgentConsumption
	rm -rf "/Applications/Agent Consumption.app"
	cp -R "$(APP)" /Applications/
	open "/Applications/Agent Consumption.app"

logs:            ## Stream the app's logs
	log stream --predicate 'subsystem == "com.goanpeca.agentconsumption"' --level info

ci: check lint security build coverage app  ## Everything CI runs (ci.yml + security.yml)

clean:
	rm -rf .build build
