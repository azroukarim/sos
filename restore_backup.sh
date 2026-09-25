#!/bin/sh
# restore_backup.sh - put back the .py files saved by compile_tool.sh
# Usage: /bin/sh restore_backup.sh [plugin_dir]   (default: current dir)
PLUGIN_DIR="${1:-.}"
BACKUP="$PLUGIN_DIR/.py_backup"

if [ ! -d "$BACKUP" ]; then
    echo "No backup folder (.py_backup) found in $PLUGIN_DIR"
    exit 1
fi

echo "Restoring original .py files to $PLUGIN_DIR ..."

find "$BACKUP" -name "*.py" -type f | while read -r f; do
    rel="${f#$BACKUP/}"
    dest="$PLUGIN_DIR/$rel"
    mkdir -p "$(dirname "$dest")"
    cp -f "$f" "$dest"
    base="$(basename "${rel%.py}")"
    ddir="$(dirname "$dest")"
    rm -f "$ddir/$base.so" "$ddir/$base".*.so
    echo "  restored $rel"
done

find "$PLUGIN_DIR" -type d -name "__pycache__" -exec rm -rf {} \; 2>/dev/null
rm -rf "$BACKUP"
rm -f "$PLUGIN_DIR/restore_backup.sh"

echo ""
echo "Done. Original .py files restored (compiled .so removed)."
echo "Restart Enigma2 to take effect: killall -9 enigma2"