
1

python3 << 'PYEOF'
file = '/usr/lib/enigma2/python/Plugins/Extensions/XPortal/provider_selection.py'
lines = open(file).readlines()
new_lines = []
for i, line in enumerate(lines):
    # احذف سطور "import os" التي تبدأ بمسافة (داخل الدوال)، واحتفظ بالسطر الأول فقط (في أعلى الملف)
    if line.strip() == 'import os' and line.startswith(' '):
        print(f"Removed local 'import os' at line {i+1}")
        continue
    new_lines.append(line)
open(file, 'w').writelines(new_lines)
print("Done! File fixed.")
PYEOF
--------------------------------------------------------------------------
2

/tmp/compile_tool.sh

-------------------------
