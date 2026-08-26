#!/bin/sh

echo "=================================================="
echo "    Enigma2 Plugins Cython Compiler Tool v2"
echo "=================================================="
echo -n "Please enter the plugin folder name or full path: "
read USER_INPUT

USER_INPUT=$(echo "$USER_INPUT" | xargs)

if [ -z "$USER_INPUT" ]; then
    echo "Error: No plugin folder or path entered."
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

echo "=================================================="
echo "Target Directory: $PLUGIN_DIR"
echo "=================================================="

echo "=== Step 1: Installing/Checking compiler & python tools ==="
opkg update
opkg install python3-dev gcc python3-setuptools python3-modules

echo "=== Step 2: Bootstrapping pip & Cython ==="
PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null)
echo "Detected Python version: $PYTHON_VERSION"

if ! command -v pip3 >/dev/null 2>&1; then
    echo "Installing pip for Python $PYTHON_VERSION..."
    if [ "$PYTHON_VERSION" = "3.5" ]; then
        curl -kLs https://bootstrap.pypa.io/pip/3.5/get-pip.py -o /tmp/get-pip.py || wget --no-check-certificate https://bootstrap.pypa.io/pip/3.5/get-pip.py -O /tmp/get-pip.py
    else
        curl -kLs https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py || wget --no-check-certificate https://bootstrap.pypa.io/get-pip.py -O /tmp/get-pip.py
    fi
    python3 /tmp/get-pip.py
    rm -f /tmp/get-pip.py
fi

pip3 install cython==0.29.36

if ! python3 -c "import Cython" 2>/dev/null; then
    echo "ERROR: Cython installation failed!"
    exit 1
fi
echo "Cython installed successfully!"

echo "=== Step 3: Finding GCC ==="
GCC_PATH=$(which gcc 2>/dev/null)
if [ -z "$GCC_PATH" ]; then
    export PATH=$PATH:/usr/bin:/usr/local/bin
    GCC_PATH=$(which gcc 2>/dev/null)
fi
if [ -z "$GCC_PATH" ]; then
    echo "WARNING: gcc not found, trying anyway..."
else
    echo "GCC found at: $GCC_PATH"
fi

echo "=== Step 4: Compiling plugin files ==="
cd "$PLUGIN_DIR"

echo "=== Fixing Python 2/3 compatibility issues ==="
find . -name "*.py" -exec grep -l "unichr" {} \; 2>/dev/null | while read f; do
    echo "Fixing unichr in: $f"
    sed -i 's/_chr = unichr/_chr = chr/g' "$f"
done

cat << 'INNER_EOF' > compile_temp.py
import os
import shutil
import subprocess
import sys

py_files = []
for root, dirs, files in os.walk('.'):
    for file in files:
        if file.endswith('.py') and file not in ['setup.py', 'compile_temp.py', '__init__.py']:
            py_files.append(os.path.join(root, file))

if not py_files:
    print("No Python files found to compile!")
    sys.exit(1)

print(f"Found {len(py_files)} Python files to compile")
for f in py_files:
    print(f"  - {f}")

setup_content = """
from setuptools import setup
from Cython.Build import cythonize
import os

py_files = %s

setup(
    ext_modules=cythonize(py_files, compiler_directives={'language_level': "3"})
)
""" % repr(py_files)

with open('setup.py', 'w') as f:
    f.write(setup_content)

print("\nStarting Cython compilation...")
result = subprocess.run([sys.executable, 'setup.py', 'build_ext', '--inplace'])

if result.returncode == 0:
    print("\nCompilation successful! Cleaning up source files...")
    if os.path.exists('setup.py'):
        os.remove('setup.py')

    for root, dirs, files in os.walk('.'):
        for file in files:
            file_path = os.path.join(root, file)
            if file.endswith('.py') and file not in ['__init__.py', 'compile_temp.py']:
                os.remove(file_path)
            elif file.endswith('.c'):
                os.remove(file_path)

    if os.path.exists('build'):
        shutil.rmtree('build')
    print("Compilation and cleanup complete!")
else:
    print("\nCompilation failed!")
    if os.path.exists('setup.py'):
        os.remove('setup.py')
    sys.exit(1)
INNER_EOF

python3 compile_temp.py
RESULT=$?
rm -f compile_temp.py

if [ $RESULT -eq 0 ]; then
    echo ""
    echo "=== SUCCESS! Compiled .so files: ==="
    find . -name "*.so" -type f
    echo ""
    echo "=== Step 5: Restarting Enigma2 ==="
    echo "Restarting GUI in 3 seconds..."
    sleep 3
    killall -9 enigma2
else
    echo ""
    echo "=== COMPILATION FAILED ==="
    echo "Please check the errors above."
fi
