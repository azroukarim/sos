#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
XPortal - Cython Build Script (Universal)
يجمّع كل ملفات .py إلى .so ملف بملف
يتخطى الملفات الفاشلة ويكمل التجميع

الاستخدام على الريسيفر:
    cd /usr/lib/enigma2/python/Plugins/Extensions/XPortal
    python setup_universal.py
"""
import os
import sys
import shutil
import subprocess

# =============================================
# الإعدادات
# =============================================

# الملفات التي لا نريد تجميعها أبداً
EXCLUDE_FILES = [
    '__init__.py',
    'setup.py',
    'setup_universal.py',
    'plugin.py',          # يحتوي imports من Enigma2 تسبب مشاكل مع Cython
]

# المجلدات التي نتجاهلها (لا تحتوي .py أو لا نريد تجميعها)
EXCLUDE_DIRS = ['build', '__pycache__', '.git', 'dist',
                'fonts', 'skin', 'ratings', 'lang']

# =============================================
# جمع الملفات المطلوب تجميعها
# =============================================
def collect_python_files(base_dir='.'):
    """جمع كل ملفات .py مع استثناء الملفات المحددة"""
    files = []
    for root, dirs, filenames in os.walk(base_dir):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]

        for filename in filenames:
            if not filename.endswith('.py'):
                continue
            if filename in EXCLUDE_FILES:
                continue

            filepath = os.path.join(root, filename)
            if filepath.startswith('./') or filepath.startswith('.\\'):
                filepath = filepath[2:]

            files.append(filepath)
    return files


# =============================================
# تجميع ملف واحد
# =============================================
def compile_single_file(filepath):
    """
    يجمّع ملف .py واحد إلى .so باستخدام Cython.
    يعيد True عند النجاح، False عند الفشل.
    """
    module_name = filepath[:-3].replace(os.sep, '.').replace('/', '.')

    setup_code = '''
import sys
try:
    from setuptools import setup, Extension
    from Cython.Build import cythonize
    ext = Extension("{module}", ["{filepath}"])
    setup(
        name="{module}",
        ext_modules=cythonize(
            [ext],
            compiler_directives={{"language_level": "3"}},
            quiet=True,
        ),
        script_args=["build_ext", "--inplace"],
    )
except ImportError:
    from distutils.core import setup
    from distutils.extension import Extension
    from Cython.Distutils import build_ext
    ext = Extension("{module}", ["{filepath}"])
    setup(
        name="{module}",
        cmdclass={{"build_ext": build_ext}},
        ext_modules=[ext],
        script_args=["build_ext", "--inplace"],
    )
'''.format(module=module_name, filepath=filepath.replace('\\', '/'))

    tmp_setup = '_tmp_setup_{}.py'.format(module_name.replace('.', '_'))
    try:
        with open(tmp_setup, 'w') as f:
            f.write(setup_code)

        result = subprocess.run(
            [sys.executable, tmp_setup],
            capture_output=True,
            text=True,
            timeout=120,
        )

        if result.returncode == 0:
            return True
        else:
            stderr = result.stderr.strip() if result.stderr else ""
            if stderr:
                lines = stderr.splitlines()
                print("    ERROR: {}".format('\n    '.join(lines[-2:])))
            return False

    except subprocess.TimeoutExpired:
        print("    TIMEOUT: تجاوز الحد الزمني (120 ثانية)")
        return False
    except Exception as e:
        print("    ERROR: {}".format(str(e)))
        return False
    finally:
        if os.path.exists(tmp_setup):
            os.remove(tmp_setup)


# =============================================
# إعادة تسمية ملفات .so
# =============================================
def rename_so_files(base_dir='.'):
    """
    يُعيد تسمية ملفات .so من الاسم الطويل إلى البسيط:
    series_sidebar.cpython-314-arm-linux-gnueabihf.so  ->  series_sidebar.so
    """
    import re
    count = 0
    pattern = re.compile(r'^(.+?)\.cpython-[^.]+\.so$')

    for root, dirs, files in os.walk(base_dir):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        for f in files:
            m = pattern.match(f)
            if not m:
                continue
            simple_name = m.group(1) + '.so'
            old_path = os.path.join(root, f)
            new_path = os.path.join(root, simple_name)
            # إذا يوجد ملف بالاسم البسيط مسبقاً احذفه
            if os.path.exists(new_path):
                os.remove(new_path)
            os.rename(old_path, new_path)
            print("  {} -> {}".format(f, simple_name))
            count += 1
    return count


# =============================================
# تنظيف ملفات .c المتبقية
# =============================================
def cleanup_c_files(base_dir='.'):
    """حذف ملفات .c التي أنشأها Cython"""
    count = 0
    for root, dirs, files in os.walk(base_dir):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        for f in files:
            if f.endswith('.c'):
                c_path = os.path.join(root, f)
                py_path = c_path[:-2] + '.py'
                if os.path.exists(py_path):
                    os.remove(c_path)
                    count += 1
    return count


# =============================================
# التشغيل الرئيسي
# =============================================
def main():
    print("=" * 55)
    print("  XPortal - Cython Build")
    print("=" * 55)

    # تحقق من Cython
    try:
        import Cython
        print("  Python: {}".format(sys.version.split()[0]))
        print("  Cython: {}".format(Cython.__version__))
    except ImportError:
        print("\n[!] Cython غير مثبت! نفّذ: pip3 install cython")
        return

    # جمع الملفات
    py_files = collect_python_files()

    if not py_files:
        print("\n[!] لا توجد ملفات .py للتجميع!")
        return

    print("\n[*] عدد الملفات للتجميع: {}".format(len(py_files)))
    print("[*] المستثناة: {}".format(', '.join(EXCLUDE_FILES)))
    print("-" * 55)

    success = []
    failed = []
    skipped = []

    for i, filepath in enumerate(py_files, 1):
        print("\n[{}/{}] {}".format(i, len(py_files), filepath))

        # تحقق من وجود ملف .so مسبقاً (مطابقة دقيقة)
        file_dir = os.path.dirname(filepath) or '.'
        base_name = os.path.splitext(os.path.basename(filepath))[0]
        existing_so = [f for f in os.listdir(file_dir)
                       if (f == base_name + '.so' or
                           f.startswith(base_name + '.cpython')) and f.endswith('.so')]

        if existing_so:
            print("  -> يوجد .so مسبق: {} (تخطي)".format(existing_so[0]))
            skipped.append(filepath)
            continue

        if compile_single_file(filepath):
            print("  -> OK ✓")
            success.append(filepath)
        else:
            print("  -> FAIL ✗")
            failed.append(filepath)

    # إعادة تسمية ملفات .so
    print("\n[*] إعادة تسمية ملفات .so ...")
    renamed = rename_so_files()
    if renamed == 0:
        print("  (لا توجد ملفات للتسمية)")

    # تنظيف
    c_count = cleanup_c_files()
    if os.path.exists('build'):
        shutil.rmtree('build', ignore_errors=True)

    # =============================================
    # تقرير النتائج
    # =============================================
    print("\n" + "=" * 55)
    print("  تقرير التجميع - XPortal")
    print("=" * 55)
    print("  نجح:    {} ✓".format(len(success)))
    print("  فشل:    {} ✗".format(len(failed)))
    print("  تخطي:   {} ⊘".format(len(skipped)))
    print("  تسمية:  {} ملف .so".format(renamed))
    print("  تنظيف:  {} ملف .c محذوف".format(c_count))

    if failed:
        print("\n  الملفات الفاشلة:")
        for f in failed:
            print("    - {}".format(f))

    print("=" * 55)

    # =============================================
    # تحقق من ملفات .py بدون .so (خطر!)
    # =============================================
    print("\n[*] فحص الملفات بدون .so ...")
    missing_so = []
    for filepath in py_files:
        file_dir = os.path.dirname(filepath) or '.'
        base_name = os.path.splitext(os.path.basename(filepath))[0]
        has_so = any(
            (f == base_name + '.so' or f.startswith(base_name + '.cpython')) and f.endswith('.so')
            for f in os.listdir(file_dir)
        )
        if not has_so:
            missing_so.append(filepath)

    if missing_so:
        print("\n  ⚠️  هذه الملفات ليس لها .so — يجب إبقاء .py الخاص بها!")
        for f in missing_so:
            print("    - {}".format(f))
        print("\n  لا تحذف ملفات .py من الريسيفر!")
        print("  Python ستستخدمها كـ fallback تلقائياً.")
    else:
        print("  كل الملفات لها .so ✓")

    print("=" * 55)

    if failed:
        print("\n[!] بعض الملفات لم تُجمّع. أعد المحاولة")
        print("    (الملفات الناجحة تُتخطى تلقائياً).")
    else:
        print("\n[✓] تم تجميع جميع الملفات بنجاح!")


if __name__ == '__main__':
    main()
