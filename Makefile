.PHONY: generate build test ipa clean

generate:
	xcodegen generate

build: generate
	xcodebuild -project CarPlayW.xcodeproj -scheme CarPlayW -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build

test: generate
	xcodebuild -project CarPlayW.xcodeproj -scheme CarPlayW -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' CODE_SIGNING_ALLOWED=NO test

ipa:
	./scripts/build-ipa.sh

clean:
	xcodebuild -project CarPlayW.xcodeproj -scheme CarPlayW clean || true
	rm -rf build Payload
