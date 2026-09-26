APP_NAME = Wallpaper
SAVER_NAME = WallpaperSaver
BUNDLE_ID_APP = com.voxel.premiumwallpaper
BUNDLE_ID_SAVER = com.voxel.premiumscreensaver

all: app saver

app:
	@echo "Building $(APP_NAME).app..."
	@mkdir -p build/$(APP_NAME).app/Contents/MacOS
	@mkdir -p build/$(APP_NAME).app/Contents/Resources
	swiftc -g -target arm64-apple-macos14.2 -o build/$(APP_NAME).app/Contents/MacOS/$(APP_NAME) Sources/App/*.swift Sources/Core/*.swift -framework Cocoa -framework WebKit -framework CoreAudio -framework Accelerate
	@cp Resources/App-Info.plist build/$(APP_NAME).app/Contents/Info.plist
	@cp Resources/index.html Resources/three.min.js build/$(APP_NAME).app/Contents/Resources/
	codesign --force --deep --sign - build/$(APP_NAME).app
	@echo "$(APP_NAME).app built successfully."

saver:
	@echo "Building $(SAVER_NAME).saver..."
	@mkdir -p build/$(SAVER_NAME).saver/Contents/MacOS
	@mkdir -p build/$(SAVER_NAME).saver/Contents/Resources
	swiftc -g -target arm64-apple-macos14.2 -emit-library -o build/$(SAVER_NAME).saver/Contents/MacOS/$(SAVER_NAME) Sources/Saver/*.swift Sources/Core/*.swift -framework Cocoa -framework WebKit -framework ScreenSaver -framework CoreAudio -framework Accelerate
	@cp Resources/Saver-Info.plist build/$(SAVER_NAME).saver/Contents/Info.plist
	@cp Resources/index.html Resources/three.min.js build/$(SAVER_NAME).saver/Contents/Resources/
	@echo "$(SAVER_NAME).saver built successfully."

check:
	swiftc -target arm64-apple-macos14.2 -o /tmp/audio_bins_check Checks/audio_bins_check.swift Sources/Core/AudioBins.swift
	/tmp/audio_bins_check

clean:
	rm -rf build/*
