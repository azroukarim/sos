#!/bin/sh

VERSION="v4.2"

echo "=================================================="
echo "   Enigma2 Plugins Cython Compiler $VERSION"
echo "   (auto backup + restore + Py2/Py3 support)"
echo "=================================================="

# ---------------------------------------------------------------
# 1) Choose the plugin directory
# ---------------------------------------------------------------
echo -n "Enter plugin folder name or full path: "
read USER_INPUT

USER_INPUT=$(echo "$USER_INPUT" | xargs)

if [ -z "$USER_INPUT" ]; then
    echo "Error: No input!"
    exit 1
fi

if echo "$USER_INPUT" | grep -q "^/"; then
    PLUGIN_DIR="$USER_INPUT"
else
    PLUGIN_DIR="/usr/lib/enigma2/python/Plugins/Extensions/$USER_INPUT"
fi

if [ ! -d "$PLUGIN_DIR" ]; then
    echo "Error: Directory $PLUGIN_DIR does not exist."
    exit 1
fi

echo "Target: $PLUGIN_DIR"

# ---------------------------------------------------------------
# 2) Detect Python version
#    Py3  -> new images (OpenATV 7.x / OpenPLi 8+ / OpenVIX 5.4+)
#    Py2  -> old images / old mipsel boxes
# ---------------------------------------------------------------
if command -v python3 >/dev/null 2>&1; then
    PYTHON="python3"
    PIPCMD="pip3"
    LANG_LEVEL=3
    PYDEV="python3-dev"
    PYEXTRA="python3-setuptools python3-modules python3-pip"
    PIP_BOOTSTRAP="https://bootstrap.pypa.io/pip/3.5/get-pip.py"
else
    PYTHON="python"
    PIPCMD="pip"
    LANG_LEVEL=2
    PYDEV="python-dev"
    PYEXTRA="python-setuptools python-modules python-pip"
    PIP_BOOTSTRAP="https://bootstrap.pypa.io/pip/2.7/get-pip.py"
fi

echo "Detected interpreter: $PYTHON (Cython language_level = $LANG_LEVEL)"

# ---------------------------------------------------------------
# 3) Install packages (gcc + python dev headers are REQUIRED)
# ---------------------------------------------------------------
echo ""
echo "=== Step 1: Installing packages ==="
opkg update >/dev/null 2>&1

echo "[i] Installing gcc and python dev headers..."
opkg install gcc "$PYDEV" 2>&1 | tail -n 3
# Some images call the package python3-devel / python-devel
opkg install "${PYDEV%-dev}-devel" 2>&1 | tail -n 2 || true

echo "[i] Installing optional python packages (setuptools, modules, pip)..."
for p in $PYEXTRA; do
    opkg install "$p" >/dev/null 2>&1 || true
done

# ---------------------------------------------------------------
# 4) Install pip (ensurepip -> bootstrap script -> opkg fallback)
# ---------------------------------------------------------------
echo ""
echo "=== Step 2: Installing pip ==="
if ! command -v "$PIPCMD" >/dev/null 2>&1; then
    "$PYTHON" -m ensurepip --upgrade >/dev/null 2>&1
fi

if ! command -v "$PIPCMD" >/dev/null 2>&1; then
    if command -v curl >/dev/null 2>&1; then
        curl -kLs "$PIP_BOOTSTRAP" -o /tmp/get-pip.py
    else
        wget --no-check-certificate "$PIP_BOOTSTRAP" -O /tmp/get-pip.py 2>/dev/null
    fi
    if [ -s /tmp/get-pip.py ]; then
        "$PYTHON" /tmp/get-pip.py >/dev/null 2>&1
        rm -f /tmp/get-pip.py
    fi
fi

if ! command -v "$PIPCMD" >/dev/null 2>&1; then
    opkg install "${PYDEV%-dev}-pip" >/dev/null 2>&1 || true
fi

if ! command -v "$PIPCMD" >/dev/null 2>&1; then
    echo "ERROR: pip is not available. Install pip manually then run again."
    exit 1
fi

# ---------------------------------------------------------------
# 5) Install Cython - choose the right version for the Python:
#    - Python 3.12+ (e.g. 3.14 on new Vu+/OpenATV images) NEEDS a
#      recent Cython; 0.29.x generates C incompatible with 3.14
#      headers ("_PyLong_AsByteArray ... expected 6, have 5").
#    - Old Python 2.7 / 3.5 images must use 0.29.36 instead.
# ---------------------------------------------------------------
echo ""
echo "=== Step 3: Installing Cython ==="

PY_MAJOR=$("$PYTHON" -c 'import sys; print(sys.version_info[0])' 2>/dev/null)
PY_MINOR=$("$PYTHON" -c 'import sys; print(sys.version_info[1])' 2>/dev/null)

NEED_NEW_CYTHON=0
if [ "$LANG_LEVEL" = "3" ]; then
    if [ -n "$PY_MAJOR" ] && [ "$PY_MAJOR" -ge 3 ] && [ -n "$PY_MINOR" ] && [ "$PY_MINOR" -ge 12 ]; then
        NEED_NEW_CYTHON=1
    fi
fi

if [ "$NEED_NEW_CYTHON" = "1" ]; then
    echo "[i] Python $PY_MAJOR.$PY_MINOR detected -> installing latest Cython..."
    "$PIPCMD" install --no-cache-dir -U cython 2>&1 | tail -n 3
    if ! "$PYTHON" -c "import Cython" >/dev/null 2>&1; then
        echo "[i] Latest Cython failed -> trying 0.29.36..."
        "$PIPCMD" install --no-cache-dir cython==0.29.36 2>&1 | tail -n 3
    fi
else
    echo "[i] Standard/old Python detected -> installing Cython 0.29.36..."
    "$PIPCMD" install --no-cache-dir cython==0.29.36 2>&1 | tail -n 3
    if ! "$PYTHON" -c "import Cython" >/dev/null 2>&1; then
        echo "[i] Cython 0.29.36 failed on this image - trying latest..."
        "$PIPCMD" install --no-cache-dir cython 2>&1 | tail -n 3
    fi
fi

if ! "$PYTHON" -c "import Cython" >/dev/null 2>&1; then
    echo "ERROR: Cython could not be installed."
    echo "On old images, try: opkg install python-cython"
    exit 1
fi
"$PYTHON" -c "import Cython; print('Cython version:', Cython.__version__)"

# ---------------------------------------------------------------
# 6) Fix libatomic (needed by some images at link time)
# ---------------------------------------------------------------
echo ""
echo "=== Step 4: Fixing libatomic as-needed ==="
if command -v gcc >/dev/null 2>&1; then
    echo "" | gcc -shared -x c - -o /usr/lib/libatomic_asneeded.so 2>/dev/null
fi

# ---------------------------------------------------------------
# 7) Python 3 compatibility fix (unichr -> chr) on Py3 only
# ---------------------------------------------------------------
echo ""
echo "=== Step 5: Applying Python compatibility fixes ==="
if [ "$LANG_LEVEL" = "3" ]; then
    find "$PLUGIN_DIR" -name "*.py" -exec grep -l "_chr = unichr" {} \; 2>/dev/null | while read -r F; do
        sed -i 's/_chr = unichr/_chr = chr/g' "$F"
        echo "  patched: $F"
    done
fi

# ---------------------------------------------------------------
# 8) Compile (an automatic backup of all .py is created first)
# ---------------------------------------------------------------
echo ""
echo "=== Step 6: Compiling (backup of .py created automatically) ==="
cd "$PLUGIN_DIR" || exit 1

cat << 'PYEOF' > /tmp/do_compile.py
import os
import shutil
import subprocess
import sys
import time

target = sys.argv[1]
lang_level = int(sys.argv[2])

os.chdir(target)

BACKUP_DIR = '.py_backup'
LOG_NAME = 'compile_log.txt'
EXCLUDE_NAMES = ('__init__.py', 'setup.py', 'compile_all.py', 'do_compile.py',
                 LOG_NAME, 'restore_backup.sh')
HIDDEN_DIRS = ('.py_backup', '.git', '__pycache__')

log_path = os.path.join(target, LOG_NAME)
log = open(log_path, 'w')

def log_line(msg):
    line = str(msg)
    sys.stdout.write(line + "\n")
    sys.stdout.flush()
    try:
        log.write(line + "\n")
        log.flush()
    except Exception:
        pass

def walk(root):
    """os.walk that never enters hidden/backup directories."""
    for r, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in HIDDEN_DIRS]
        yield r, files

def makedirs(path):
    try:
        os.makedirs(path)
    except OSError:
        pass

log_line("=== Enigma2 Cython Compile Log ===")
log_line("Time:            %s" % time.asctime())
log_line("Target:          %s" % target)
log_line("language_level:  %d" % lang_level)

# ---------------------------------------------------------------
# 1) Discover .py files  (__init__.py is ALWAYS excluded)
# ---------------------------------------------------------------
py_files = []
for r, files in walk('.'):
    for f in files:
        if f.endswith('.py') and f not in EXCLUDE_NAMES:
            py_files.append(os.path.join(r, f))
py_files.sort()

log_line("Found %d Python file(s) to compile:" % len(py_files))
for p in py_files:
    log_line("  -> %s" % p)

if not py_files:
    log_line("No Python files found! Aborting (nothing was deleted).")
    log.close()
    sys.exit(1)

# ---------------------------------------------------------------
# 2) Backup originals BEFORE touching anything
# ---------------------------------------------------------------
backup_root = os.path.join(target, BACKUP_DIR)
if os.path.exists(backup_root):
    shutil.rmtree(backup_root)
makedirs(backup_root)

log_line("Backing up originals to %s ..." % backup_root)
for rel in py_files:
    dest = os.path.join(backup_root, rel)
    makedirs(os.path.dirname(dest))
    shutil.copy2(rel, dest)

with open(os.path.join(backup_root, 'manifest.txt'), 'w') as mf:
    mf.write("Backup created: %s\n" % time.asctime())
    for rel in py_files:
        mf.write(rel + "\n")
log_line("Backup done (%d file(s))." % len(py_files))

# ---------------------------------------------------------------
# 3) Write setup.py
# ---------------------------------------------------------------
setup_content = (
    "from setuptools import setup\n"
    "from Cython.Build import cythonize\n"
    "import sysconfig\n"
    "\n"
    "# strip the -latomic_asneeded flag some images inject\n"
    "config_vars = sysconfig.get_config_vars()\n"
    "for key in ('LDSHARED', 'LDFLAGS', 'CCSSHARED', 'LDSHAREDXX'):\n"
    "    if key in config_vars and isinstance(config_vars[key], str):\n"
    "        config_vars[key] = config_vars[key].replace('-latomic_asneeded', '')\n"
    "\n"
    "py_files = %r\n" % py_files
)
setup_content += (
    "\n"
    "setup(\n"
    "    ext_modules=cythonize(py_files, compiler_directives={'language_level': %d})\n"
    ")\n" % lang_level
)

setup_path = os.path.join(target, 'setup.py')
with open(setup_path, 'w') as f:
    f.write(setup_content)

# ---------------------------------------------------------------
# 4) Run the build (output streamed to console AND the log)
# ---------------------------------------------------------------
log_line("Starting Cython compilation...")
cmd = [sys.executable, 'setup.py', 'build_ext', '--inplace']
proc = subprocess.Popen(cmd, cwd=target, stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT, universal_newlines=True)
for line in iter(proc.stdout.readline, ''):
    log_line(line.rstrip('\n'))
proc.wait()
rc = proc.returncode

try:
    os.remove(setup_path)
except OSError:
    pass

if rc != 0:
    log_line("")
    log_line("COMPILATION FAILED - original .py files were NOT deleted.")
    log_line("Backup still available at: %s" % backup_root)
    # remove generated .c files only, keep every .py intact
    for r, files in walk('.'):
        for f in files:
            if f.endswith('.c'):
                try:
                    os.remove(os.path.join(r, f))
                except OSError:
                    pass
    try:
        shutil.rmtree('build', ignore_errors=True)
    except Exception:
        pass
    log.close()
    sys.exit(1)

# ---------------------------------------------------------------
# 5) Relocate any misplaced .so (some images put them in a nested
#    folder named after the plugin, e.g. XPortal/XPortal/plugin.so).
#    We force every .so to sit right next to its original .py file.
# ---------------------------------------------------------------
wanted = {}
for rel in py_files:
    d = os.path.normpath(os.path.dirname(rel)) or '.'
    leaf = os.path.splitext(os.path.basename(rel))[0]
    if leaf not in wanted:
        wanted[leaf] = d

for r, files in walk('.'):
    for f in files:
        if not f.endswith('.so'):
            continue
        cur = os.path.normpath(os.path.join(r, f))
        leaf = f[:-3]
        if '.' in leaf:
            leaf = leaf.split('.')[0]
        if leaf not in wanted:
            continue
        dest = os.path.normpath(os.path.join(wanted[leaf], f))
        if dest != cur:
            try:
                shutil.move(cur, dest)
                log_line("  relocated %s -> %s" % (cur, dest))
            except OSError as e:
                log_line("  relocate failed %s (%s)" % (cur, e))

# ---------------------------------------------------------------
# 6) Success: remove compiled .py and .c (originals stay in backup)
# ---------------------------------------------------------------
log_line("Compilation successful. Cleaning up compiled sources...")
for r, files in walk('.'):
    for f in files:
        p = os.path.join(r, f)
        if f.endswith('.c') or (f.endswith('.py') and f not in EXCLUDE_NAMES):
            try:
                os.remove(p)
                log_line("  removed %s" % p)
            except OSError as e:
                log_line("  skip %s (%s)" % (p, e))

try:
    shutil.rmtree('build', ignore_errors=True)
except Exception:
    pass

def prune_empty(root):
    """Remove directories left empty by relocating .so files."""
    for r, dirs, files in os.walk(root, topdown=False):
        for d in dirs:
            p = os.path.join(r, d)
            if d in HIDDEN_DIRS:
                continue
            try:
                if not os.listdir(p):
                    os.rmdir(p)
                    log_line("  removed empty dir %s" % p)
            except OSError:
                pass

prune_empty('.')

# ---------------------------------------------------------------
# 7) Drop a restore script next to the plugin
# ---------------------------------------------------------------
RESTORE_SCRIPT = """#!/bin/sh
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

find "$PLUGIN_DIR" -type d -name "__pycache__" -exec rm -rf {} \\; 2>/dev/null
rm -rf "$BACKUP"
rm -f "$PLUGIN_DIR/restore_backup.sh"

echo ""
echo "Done. Original .py files restored (compiled .so removed)."
echo "Restart Enigma2 to take effect: killall -9 enigma2"
"""

restore_path = os.path.join(target, 'restore_backup.sh')
with open(restore_path, 'w') as f:
    f.write(RESTORE_SCRIPT)
try:
    os.chmod(restore_path, 0o755)
except Exception:
    pass

so_files = []
for r, files in walk('.'):
    for f in files:
        if f.endswith('.so'):
            so_files.append(os.path.join(r, f))

log_line("")
log_line("Done! Created %d .so file(s):" % len(so_files))
for s in so_files:
    log_line("  %s" % s)

log.close()
print("")
print("Backup:       %s/%s" % (target, BACKUP_DIR))
print("Log:          %s/%s" % (target, LOG_NAME))
print("Restore:      /bin/sh %s/restore_backup.sh" % target)
print("")
PYEOF

"$PYTHON" /tmp/do_compile.py "$PLUGIN_DIR" "$LANG_LEVEL"
COMPILE_RC=$?
rm -f /tmp/do_compile.py

if [ "$COMPILE_RC" -ne 0 ]; then
    echo ""
    echo "Compilation FAILED - original .py files were NOT deleted."
    echo "Check the log: $PLUGIN_DIR/compile_log.txt"
    exit 1
fi

echo ""
echo "=== Finished ==="
find "$PLUGIN_DIR" -name "*.so" -type f | grep -v "/.py_backup/"
echo ""
echo "Backup of original .py: $PLUGIN_DIR/.py_backup"
echo "Log file:               $PLUGIN_DIR/compile_log.txt"
echo "Restore anytime:        /bin/sh $PLUGIN_DIR/restore_backup.sh"
echo ""
echo -n "Restart Enigma2 now? (y/N): "
read RESTART_ANSWER
case "$RESTART_ANSWER" in
    y|Y|yes|YES|Yes) killall -9 enigma2 ;;
    *) echo "Skipped. To load the compiled plugin later run: killall -9 enigma2" ;;
esac