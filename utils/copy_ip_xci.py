import os
import shutil

src = '.'
dst = '../copy'

os.mkdir(dst)
for f1 in os.listdir(src):
    if os.path.isdir(f1):
        os.mkdir(os.path.join(dst, f1))
        for f2 in os.listdir(f1):
            f2_path = os.path.join(f1, f2)
            if f2.split('.')[-1] == 'xci':
                shutil.copy(f2_path, os.path.join(dst, f2_path))
        