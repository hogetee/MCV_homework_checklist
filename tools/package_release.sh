#!/bin/bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
export DEVELOPER_DIR
PREVIEW=0
NOTARY_PROFILE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --development-preview) PREVIEW=1; shift ;;
        --notary-profile)
            [[ $# -ge 2 ]] || { echo "--notary-profile needs a Keychain profile name." >&2; exit 1; }
            NOTARY_PROFILE="$2"; shift 2 ;;
        *) echo "Usage: bash tools/package_release.sh --development-preview | --notary-profile NAME" >&2; exit 1 ;;
    esac
done
if [[ "$PREVIEW" -eq 0 && -z "$NOTARY_PROFILE" ]]; then
    echo "A public distribution needs Developer ID signing and a notary Keychain profile." >&2
    echo "For an explicitly unnotarized trial build, pass --development-preview." >&2
    exit 1
fi

APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/App/Info.plist")"
WIDGET_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Widget/Info.plist")"
[[ "$APP_VERSION" == "$WIDGET_VERSION" ]] || { echo "App/widget versions differ." >&2; exit 1; }
WORK="$(/usr/bin/mktemp -d "${TMPDIR:-/private/tmp}/MCVNotRelease.XXXXXX")"
MOUNT="$WORK/Mounted"
MOUNTED=0
cleanup() {
    if [[ "$MOUNTED" -eq 1 ]] && ! /usr/bin/hdiutil detach -quiet "$MOUNT"; then
        echo "Could not detach the temporary installer image; kept $WORK for cleanup." >&2
        return 1
    fi
    /bin/rm -rf "$WORK"
}
trap cleanup EXIT
OUTPUT="$ROOT/Build/Release"
/bin/mkdir -p "$OUTPUT" "$WORK/Image"
SIGNER="Developer ID Application"
if [[ "$PREVIEW" -eq 1 ]]; then SIGNER="Apple Development"; fi

"$DEVELOPER_DIR/usr/bin/xcodebuild" \
    -project "$ROOT/MCVNot.xcodeproj" -scheme MCVNot -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath "$WORK/DerivedData" \
    ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY="$SIGNER" \
    ENABLE_HARDENED_RUNTIME=YES CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO build -quiet

APP="$WORK/DerivedData/Build/Products/Release/MCVNot.app"
WIDGET="$APP/Contents/PlugIns/MCVWidget.appex"
/usr/bin/codesign --verify --deep --strict "$APP"
for executable in "$APP/Contents/MacOS/MCVNot" "$WIDGET/Contents/MacOS/MCVWidget"; do
    ARCHITECTURES=" $(/usr/bin/lipo -archs "$executable") "
    [[ "$ARCHITECTURES" == *" arm64 "* && "$ARCHITECTURES" == *" x86_64 "* ]] || {
        echo "App and widget must support both arm64 and x86_64." >&2; exit 1;
    }
done
for bundle in "$APP" "$WIDGET"; do
    /usr/bin/codesign -d --verbose=2 "$bundle" > "$WORK/signature.txt" 2>&1
    /usr/bin/grep -Fq "Authority=$SIGNER:" "$WORK/signature.txt"
    /usr/bin/grep -Eq 'flags=.*runtime' "$WORK/signature.txt"
    /usr/bin/codesign -d --entitlements :- "$bundle" > "$WORK/entitlements.plist" 2>/dev/null
    /usr/bin/plutil -lint "$WORK/entitlements.plist" > /dev/null
    DEBUG_ALLOWED="$(/usr/bin/plutil -extract com.apple.security.get-task-allow raw -o - "$WORK/entitlements.plist" 2>/dev/null || true)"
    [[ "$DEBUG_ALLOWED" != "true" ]] || { echo "Refusing to package a debugger-enabled app." >&2; exit 1; }
done

/usr/bin/ditto "$APP" "$WORK/Image/MCVNot.app"
/bin/ln -s /Applications "$WORK/Image/Applications"
if [[ "$PREVIEW" -eq 1 ]]; then
    /bin/cp "$ROOT/docs/START-HERE-preview.txt" "$WORK/Image/เริ่มใช้.txt"
else
    /bin/cp "$ROOT/docs/START-HERE.txt" "$WORK/Image/เริ่มใช้.txt"
fi
MODE="distribution"
if [[ "$PREVIEW" -eq 1 ]]; then MODE="preview"; fi
SWIFT="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"
"$SWIFT" build --package-path "$ROOT/tools/InstallerLayout" \
    --scratch-path "$WORK/LayoutBuild" -c release --quiet
LAYOUT_BIN="$("$SWIFT" build --package-path "$ROOT/tools/InstallerLayout" \
    --scratch-path "$WORK/LayoutBuild" -c release --show-bin-path)/InstallerLayout"
/usr/bin/hdiutil create -quiet -format UDRW -fs HFS+ -volname "MCVNot $APP_VERSION" \
    -srcfolder "$WORK/Image" "$WORK/Installer.dmg"
/bin/mkdir -p "$MOUNT"
/usr/bin/hdiutil attach -quiet -nobrowse -mountpoint "$MOUNT" "$WORK/Installer.dmg"
MOUNTED=1
"$LAYOUT_BIN" "$MOUNT" "$MODE"
/bin/cp "$ROOT/App/Resources/AppIcon.icns" "$MOUNT/.VolumeIcon.icns"
"$DEVELOPER_DIR/usr/bin/SetFile" -a C "$MOUNT"
/usr/bin/hdiutil detach -quiet "$MOUNT"
MOUNTED=0
DMG="$WORK/MCVNot-$APP_VERSION-universal.dmg"
/usr/bin/hdiutil convert -quiet -format UDZO -o "$DMG" "$WORK/Installer.dmg"

if [[ "$PREVIEW" -eq 0 ]]; then
    /usr/bin/codesign --sign "$SIGNER" --timestamp "$DMG"
    /usr/bin/xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" \
        --wait --output-format json > "$WORK/notary-result.json"
    /usr/bin/plutil -extract status raw -o "$WORK/notary-status.txt" "$WORK/notary-result.json"
    [[ "$(/bin/cat "$WORK/notary-status.txt")" == "Accepted" ]] || {
        echo "Apple did not accept this upload; do not publish it." >&2; exit 1;
    }
    /usr/bin/xcrun stapler staple "$DMG"
    /usr/bin/xcrun stapler validate "$DMG"
fi
/usr/bin/hdiutil verify "$DMG"
/bin/mv "$DMG" "$OUTPUT/$(/usr/bin/basename "$DMG")"
cd "$OUTPUT"
/usr/bin/shasum -a 256 "$(/usr/bin/basename "$DMG")" > SHA256SUMS.txt
echo "Created $OUTPUT/$(/usr/bin/basename "$DMG")"
if [[ "$PREVIEW" -eq 1 ]]; then
    echo "Development preview: not notarized; first launch may need a user-approved macOS exception."
fi
