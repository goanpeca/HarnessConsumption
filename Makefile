APP := build/Agent Consumption.app

.PHONY: test build app run install clean logs

test:            ## Package tests (Swift Testing)
	swift test

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
