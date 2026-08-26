#!/bin/sh

# ترحيب وطلب مسار البلوجين
echo "=================================================="
echo "    Enigma2 Plugins Cython Compiler Tool"
echo "=================================================="
echo -n "Please enter the plugin folder name or full path: "
read USER_INPUT

# تنظيف المدخلات من الفراغات
USER_INPUT=$(echo "$USER_INPUT" | xargs)

if [ -z "$USER_INPUT" ]; then
    echo "Error: No plugin folder or path entered."
    exit 1
fi

# تحديد ما إذا كان المدخل مسار كامل أم مجرد اسم مجلد
if echo "$USER_INPUT" | grep -q "^/"; then
    PLUGIN_DIR="$USER_INPUT"
else
    PLUGIN_DIR="/usr/lib/enigma2/python/Plugins/Extensions/$USER_INPUT"
fi

# التحقق من وجود المجلد
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
if ! command -v pip3 >/dev/null 2>&1; then
    curl -kLs https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py || wget --no-check-certificate https://bootstrap.pypa.io/get-pip.py -O /tmp/get-pip.py
    python3 /tmp/get-pip.py
fi
pip3 install cython

echo "=== Step 3: Fixing libatomic_asneeded bug ==="
if [ ! -f /usr/lib/libatomic_asneeded.so ]; then
    echo "" | arm-oe-linux-gnueabi-gcc -shared -x c - -o /usr/lib/libatomic_asneeded.so || echo "" | gcc -shared -x c - -o /usr/lib/libatomic_asneeded.so
fi

echo "=== Step 4: Compiling plugin files ==="
cd "$PLUGIN_DIR"

# إنشاء سكربت التجميع المؤقت
cat << 'INNER_EOF' > compile_temp.py
import os
import shutil
import subprocess
import sys

setup_content = """
from setuptools import setup
from Cython.Build import cythonize
import glob
import os
import sysconfig

config_vars = sysconfig.get_config_vars()
for key in ['LDSHARED', 'LDFLAGS', 'CCSSHARED', 'LDSHAREDXX']:
    if key in config_vars and isinstance(config_vars[key], str):
        config_vars[key] = config_vars[key].replace('-latomic_asneeded', '')

py_files = []
for root, dirs, files in os.walk('.'):
    for file in files:
        if file.endswith('.py') and file not in ['setup.py', 'compile_temp.py', '__init__.py']:
            py_files.append(os.path.join(root, file))

setup(
    ext_modules=cythonize(py_files, compiler_directives={'language_level': "3"})
)
"""

with open('setup.py', 'w') as f:
    f.write(setup_content)

print("Starting Cython compilation...")
result = subprocess.run([sys.executable, 'setup.py', 'build_ext', '--inplace'])

if result.returncode == 0:
    print("Compilation successful! Cleaning up source files...")
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
    print("Compilation failed!")
    if os.path.exists('setup.py'):
        os.remove('setup.py')
INNER_EOF

python3 compile_temp.py
rm -f compile_temp.py

echo "=== Step 5: Restarting Enigma2 ==="
echo "Restarting GUI in 3 seconds..."
sleep 3
killall -9 enigma2
