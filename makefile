NAME := ZheeSign
PYTHON_DIR := python-ios
PLATFORM := iphoneos
SCHEMES := Ksign
TMP := $(TMPDIR)/$(NAME)
STAGE := $(TMP)/stage
APP := $(TMP)/Build/Products/Release-$(PLATFORM)

.PHONY: all clean $(SCHEMES)

all: $(SCHEMES)

clean:
	rm -rf "$(TMP)"
	rm -rf packages
	rm -rf Payload

deps:
	rm -rf deps || true
	mkdir -p deps
	curl -L -o deps/server.crt https://backloop.dev/backloop.dev-cert.crt || true
	curl -L -o deps/server.key1 https://backloop.dev/backloop.dev-key.part1.pem || true
	curl -L -o deps/server.key2 https://backloop.dev/backloop.dev-key.part2.pem || true
	cat deps/server.key1 deps/server.key2 > deps/server.pem 2>/dev/null || true
	rm -f deps/server.key1 deps/server.key2
	echo "*.backloop.dev" > deps/commonName.txt

$(SCHEMES): deps
	xcodebuild \
	    -project Ksign.xcodeproj \
	    -scheme "$@" \
	    -configuration Release \
	    -arch arm64 \
	    -sdk $(PLATFORM) \
	    -derivedDataPath $(TMP) \
	    -skipPackagePluginValidation \
	    CODE_SIGNING_ALLOWED=NO \
	    ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES=NO

	rm -rf Payload
	rm -rf "$(STAGE)/"
	mkdir -p "$(STAGE)/Payload"

	mv "$(APP)/$(NAME).app" "$(STAGE)/Payload/$(NAME).app"

	chmod -R 0755 "$(STAGE)/Payload/$(NAME).app"
	codesign --force --sign - --timestamp=none "$(STAGE)/Payload/$(NAME).app"

	cp deps/* "$(STAGE)/Payload/$(NAME).app/" || true

	# Nhung Python framework
	if [ -d "$(PYTHON_DIR)/Python.xcframework/ios-arm64/Python.framework" ]; then \
		mkdir -p "$(STAGE)/Payload/$(NAME).app/Frameworks"; \
		cp -R "$(PYTHON_DIR)/Python.xcframework/ios-arm64/Python.framework" "$(STAGE)/Payload/$(NAME).app/Frameworks/"; \
		echo "Python framework embedded"; \
	fi
	if [ -d "$(PYTHON_DIR)/python" ]; then \
		cp -R "$(PYTHON_DIR)/python" "$(STAGE)/Payload/$(NAME).app/"; \
		echo "Python stdlib copied"; \
	fi

	rm -rf "$(STAGE)/Payload/$(NAME).app/_CodeSignature"
	ln -sf "$(STAGE)/Payload" Payload
	
	mkdir -p packages
	zip -r9 "packages/$(NAME).ipa" Payload