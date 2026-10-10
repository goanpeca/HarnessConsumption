APP := build/Agent Consumption.app

.PHONY: test build app run install clean logs lint ci

test:            ## Package tests (Swift Testing)
	swift test

lint:            ## Syntax-level checks that fail on unparsable or badly formed Swift
	swift format lint --strict --recursive Sources Tests Package.swift --configuration .swift-format

ci: lint test app   ## What CI runs

build:           ## Debug build
	swift build

app:             ## Release .app bundle in build/
	scripts/bundle.sh

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

clean:
	rm -rf .build build
