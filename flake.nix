{
  description = "Nix flake devShell for building the Notesnook Android app (React Native)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            android_sdk.accept_license = true;
            allowUnfree = true;
          };
        };

        NDK_VERSION = "27.1.12297006";
        # Android SDK/NDK setup suitable for React Native
        androidSdk = pkgs.androidenv.composeAndroidPackages {
          platformVersions = [ "35" "36" ];
          buildToolsVersions = [ "35.0.0" "36.0.0" ];
          abiVersions = [ "arm64-v8a" ];
          includeNDK = true;
          ndkVersions = [ NDK_VERSION ];
          includeEmulator = false;
          includeSystemImages = false;
          includeCmake = true;
          cmakeVersions = ["3.22.1"];
        };

        androidHome = "${androidSdk.androidsdk}/libexec/android-sdk";

      in {
        devShells.default = pkgs.mkShell {
          name = "notesnook-android-shell";

          packages = with pkgs; [
            # JS / RN toolchain
            nodejs_22
            yarn
            watchman
	    python313Packages.distutils

            # Android / Java / build tools
            androidSdk.androidsdk
            jdk17

            # Native build deps commonly needed by RN
            cmake
            ninja
            pkg-config
            python3

            # Optional but handy
            git
            unzip
            which
            husky
          ];

          ANDROID_HOME = androidHome;
          ANDROID_SDK_ROOT = androidHome;
          ANDROID_NDK_ROOT = "${androidHome}/ndk/${NDK_VERSION}";
          JAVA_HOME = pkgs.jdk17.home;

          # React Native + Gradle are memory-hungry
          GRADLE_OPTS = "-Dorg.gradle.jvmargs=-Xmx4g -Dkotlin.daemon.jvm.options=-Xmx2g";

          shellHook = ''
            export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
            echo ""
            echo "📱 Notesnook Android dev shell ready"
            echo "ANDROID_HOME=$ANDROID_HOME"
            echo "JAVA_HOME=$JAVA_HOME"
            echo "Node: $(node --version)"
            echo ""

            build() {
              npm ci --ignore-scripts --prefer-offline --no-audit
              npm run bootstrap -- --scope=web
              npm run bootstrap -- --scope=desktop
              npm run build:web
              npm run build:desktop
              npm run build:android
            }
          '';
        };
      }
    );
}

