#!/bin/sh
# quick_compile.sh v2 - compile or restore Enigma2 plugins
# Usage:
#   /bin/sh quick_compile.sh compile <plugin_name_or_full_path>
#   /bin/sh quick_compile.sh restore  <plugin_name_or_full_path>
#
# Note: downloads the latest compile_tool.sh / restore_backup.sh from
# your GitHub repo. Remember to upload the new v4 files there.

BASE_URL="https://raw.githubusercontent.com/azroukarim/sos/refs/heads/main"
MODE="${1:-compile}"
PLUGIN_NAME="${2:-}"

if [ -z "$PLUGIN_NAME" ]; then
    echo "Usage:"
    echo "  /bin/sh quick_compile.sh compile <plugin>   (or full path)"
    echo "  /bin/sh quick_compile.sh restore  <plugin>  (restore .py from backup)"
    exit 1
fi

download() {
    # $1 = file name
    if command -v curl >/dev/null 2>&1; then
        curl -kLs "$BASE_URL/$1" -o "/tmp/$1"
    else
        wget --no-check-certificate "$BASE_URL/$1" -O "/tmp/$1" 2>/dev/null
    fi
    if [ ! -s "/tmp/$1" ]; then
        echo "Download of $1 failed! Check internet connection."
        exit 1
    fi
}

if [ "$MODE" = "restore" ]; then
    echo "Downloading restore script..."
    download restore_backup.sh
    chmod +x /tmp/restore_backup.sh
    /bin/sh /tmp/restore_backup.sh "$PLUGIN_NAME"
    exit $?
fi

echo "Downloading compiler tool..."
download compile_tool.sh
chmod +x /tmp/compile_tool.sh
echo "Running compiler for: $PLUGIN_NAME"
/bin/sh /tmp/compile_tool.sh <<EOF
$PLUGIN_NAME
EOF