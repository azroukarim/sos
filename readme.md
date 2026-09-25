
الخطوة 1: تحديث الفيد وتثبيت أدوات التطوير الأساسية
تقوم هذه الخطوات بتثبيت المترجم ومكتبات بايثون الأساسية:

opkg update
opkg install python3-dev gcc python3-setuptools python3-modules






الخطوة 2: تثبيت مدير الحزم 
pip ومكتبة Cython
بما أن بعض الصور لا تحتوي على pip، سنقوم بتحميله وتثبيته يدوياً ثم تثبيت Cython:





# تحميل سكربت تثبيت pip
curl -kLs https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py || wget --no-check-certificate https://bootstrap.pypa.io/get-pip.py -O /tmp/get-pip.py

# تثبيت pip
python3 /tmp/get-pip.py

# تثبيت Cython
pip3 install cython






الخطوة 3: حل مشكلة المترجم المفقودة (المكتبة الوهمية)
هذا الأمر يحل مشكلة الربط -latomic_asneeded الشهيرة في صور Enigma2 ويصلحها تلقائياً سواء كان اسم المترجم gcc أو arm-oe-linux-gnueabi-gcc:

echo "" | arm-oe-linux-gnueabi-gcc -shared -x c - -o /usr/lib/libatomic_asneeded.so || echo "" | gcc -shared -x c - -o /usr/lib/libatomic_asneeded.so





الخطوة 4: الانتقال إلى مجلد البلوجين وبدء التشفير

1.	ادخل إلى مجلد البلوجين الذي تريد تشفيره (استبدل XPortal باسم مجلد البلوجين الخاص بك):

cd /usr/lib/enigma2/python/Plugins/Extensions/XPortal
2.

انسخ هذا الأمر البرمجي الذكي بالكامل لإنشاء ملف التجميع الذاتي (compile_all.py)

cat << 'EOF' > compile_all.py
import os
import glob
import shutil
import subprocess
import sys

setup_content = """
from setuptools import setup
from Cython.Build import cythonize
import glob
import os
import sysconfig

# حل مشكلة الربط لـ latomic_asneeded
config_vars = sysconfig.get_config_vars()
for key in ['LDSHARED', 'LDFLAGS', 'CCSSHARED', 'LDSHAREDXX']:
    if key in config_vars and isinstance(config_vars[key], str):
        config_vars[key] = config_vars[key].replace('-latomic_asneeded', '')

# البحث عن كل ملفات py باستثناء الملفات الأساسية والتعريفية
py_files = []
for root, dirs, files in os.walk('.'):
    for file in files:
        if file.endswith('.py') and file not in ['setup.py', 'compile_all.py', '__init__.py']:
            py_files.append(os.path.join(root, file))

setup(
    ext_modules=cythonize(py_files, compiler_directives={'language_level': "3"})
)
"""

with open('setup.py', 'w') as f:
    f.write(setup_content)

print("Starting Cython compilation for all files...")
result = subprocess.run([sys.executable, 'setup.py', 'build_ext', '--inplace'])

if result.returncode == 0:
    print("Compilation successful! Cleaning up source files...")
    
    if os.path.exists('setup.py'):
        os.remove('setup.py')
        
    # حذف ملفات py الأصلية وملفات c الناتجة
    for root, dirs, files in os.walk('.'):
        for file in files:
            file_path = os.path.join(root, file)
            if file.endswith('.py') and file not in ['__init__.py', 'compile_all.py']:
                print(f"Removing source: {file_path}")
                os.remove(file_path)
            elif file.endswith('.c'):
                print(f"Removing C file: {file_path}")
                os.remove(file_path)
                
    if os.path.exists('build'):
        shutil.rmtree('build')
        print("Removed 'build' directory.")
        
    print("All done! Your plugin files are now compiled to .so files.")
    os.remove('compile_all.py') # حذف سكربت التجميع تلقائياً بعد الانتهاء
else:
    print("Compilation failed. No files were deleted.")
EOF

3.
شغّل سكربت التشفير الذاتي وانتظر حتى ينتهي:
python3 compile_all.py

4.
killall -9 enigma2

💡 تذكر دائماً: احتفظ بنسخة من ملفات البلوجين بصيغة .py الأصلية على جهاز الكمبيوتر الخاص بك احتياطياً قبل البدء





