#!/bin/bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
APP_PATH="$ROOT/MCVNot.app"
WIDGET_ID="com.mcvnot.app.widget.v2"
APP_INFO="$ROOT/App/Info.plist"
WIDGET_INFO="$ROOT/Widget/Info.plist"
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
BUILD_ROOT="$(/usr/bin/mktemp -d "${TMPDIR:-/private/tmp}/MCVNotUpdate.XXXXXX")"
STAGED_APP="$ROOT/.MCVNot-update-$$.app"
BACKUP_APP="$BUILD_ROOT/MCVNot.previous.app"
INSTALLED=0

restore_on_failure() {
    status=$?
    if [[ "$INSTALLED" -eq 0 && -d "$BACKUP_APP" ]]; then
        if [[ -e "$APP_PATH" ]]; then /bin/rm -rf "$APP_PATH"; fi
        /bin/mv "$BACKUP_APP" "$APP_PATH"
        /usr/bin/pluginkit -a "$APP_PATH/Contents/PlugIns/MCVWidget.appex" 2>/dev/null || true
        /usr/bin/pluginkit -e use -i "$WIDGET_ID" 2>/dev/null || true
    fi
    if [[ -e "$STAGED_APP" ]]; then /bin/rm -rf "$STAGED_APP"; fi
    /bin/rm -rf "$BUILD_ROOT"
    exit "$status"
}
trap restore_on_failure EXIT

APP_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_INFO")"
WIDGET_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$WIDGET_INFO")"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_INFO")"
WIDGET_VERSION_SOURCE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$WIDGET_INFO")"
if [[ "$APP_BUILD" != "$WIDGET_BUILD" || "$APP_VERSION" != "$WIDGET_VERSION_SOURCE" ]]; then
    echo "App and widget versions must match before an update." >&2
    exit 1
fi
NEXT_BUILD=$((10#$APP_BUILD + 1))
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEXT_BUILD" "$APP_INFO"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEXT_BUILD" "$WIDGET_INFO"

DEVELOPER_DIR="$DEVELOPER_DIR" /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
    -project "$ROOT/MCVNot.xcodeproj" \
    -scheme MCVNot \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath "$BUILD_ROOT/DerivedData" \
    CODE_SIGNING_ALLOWED=YES build -quiet

BUILT_APP="$BUILD_ROOT/DerivedData/Build/Products/Release/MCVNot.app"
BUILT_EXTENSION="$BUILT_APP/Contents/PlugIns/MCVWidget.appex"
WIDGET_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$BUILT_EXTENSION/Contents/Info.plist")"
if [[ ! -d "$BUILT_APP" || ! -d "$BUILT_EXTENSION" ]]; then
    echo "Build did not produce the app and widget extension." >&2
    exit 1
fi

/usr/bin/killall -TERM MCVNot 2>/dev/null || true
/usr/bin/ditto "$BUILT_APP" "$STAGED_APP"
if [[ -e "$APP_PATH" ]]; then /bin/mv "$APP_PATH" "$BACKUP_APP"; fi
/bin/mv "$STAGED_APP" "$APP_PATH"

TARGET_EXTENSION="$APP_PATH/Contents/PlugIns/MCVWidget.appex"
REGISTERED_PATHS="$(/usr/bin/pluginkit -m -v -A -D -i "$WIDGET_ID" 2>/dev/null | \
    /usr/bin/awk -F '\t' -v identifier="$WIDGET_ID" 'index($1, identifier) && NF >= 4 { print $NF }' | \
    /usr/bin/sort -u)"
while IFS= read -r plugin_path; do
    [[ -n "$plugin_path" ]] || continue
    [[ "$plugin_path" == "$TARGET_EXTENSION" ]] && continue
    /usr/bin/pluginkit -r "$plugin_path" 2>/dev/null || true
done <<< "$REGISTERED_PATHS"

"$LSREGISTER" -f -R -trusted "$APP_PATH"
/usr/bin/pluginkit -a "$TARGET_EXTENSION"
/usr/bin/pluginkit -e use -i "$WIDGET_ID"

MATCHES="$(/usr/bin/pluginkit -m -v -i "$WIDGET_ID")"
printf '%s\n' "$MATCHES"
if ! printf '%s\n' "$MATCHES" | /usr/bin/grep -Fq "+    $WIDGET_ID($WIDGET_VERSION)" || \
   ! printf '%s\n' "$MATCHES" | /usr/bin/grep -Fq "$TARGET_EXTENSION"; then
    echo "PluginKit did not select the installed widget extension in normal use." >&2
    exit 1
fi
ALL_PATHS="$(/usr/bin/pluginkit -m -v -A -D -i "$WIDGET_ID" | \
    /usr/bin/awk -F '\t' 'NF >= 4 { print $NF }' | /usr/bin/sort -u)"
if [[ "$ALL_PATHS" != "$TARGET_EXTENSION" ]]; then
    echo "A stale widget registration is still present:" >&2
    printf '%s\n' "$ALL_PATHS" >&2
    exit 1
fi

INSTALLED=1
/usr/bin/open -a "$APP_PATH"
echo "Installed MCVNot and verified WidgetKit $WIDGET_VERSION from $APP_PATH."
echo "The app syncs on launch and calls reloadAllTimelines after a successful sync."
