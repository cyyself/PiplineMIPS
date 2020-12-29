import os
import sys
import shutil

if len(sys.argv)==3:
    src = sys.argv[1]
    dst = sys.argv[2]
else:
    src = '.'
    dst = '../copy'
print('Arg:', sys.argv)
print('src: %s\ndst: %s'%(src, dst))

#testbench
src_path = os.path.join(src, 'testbench')
dst_path = os.path.join(dst, 'testbench')
shutil.copytree(src_path, dst_path)
print(dst_path)

#run_vivado
src_path = os.path.join(src, 'run_vivado')
dst_path = os.path.join(dst, 'run_vivado')
os.makedirs(dst_path)
for f1 in os.listdir(src_path): 
    f1_path = os.path.join(src_path, f1)
    f1_path_dst = os.path.join(dst_path, f1)
    if(os.path.isfile(f1_path)):                #将一级目录下的文件复制
        shutil.copy(f1_path, f1_path_dst)
        print(f1_path_dst)
    else:
        os.mkdir(f1_path_dst)
        for f2 in os.listdir(f1_path):          #将二级目录下的xpr文件复制
            f2_path = os.path.join(f1_path, f2)
            f2_path_dst = os.path.join(f1_path_dst, f2)
            if(f2.split('.')[-1]=='xpr'):
                shutil.copy(f2_path, f2_path_dst)
                print(f2_path_dst)

#rtl
src_path = os.path.join(src, 'rtl')
dst_path = os.path.join(dst, 'rtl')
os.makedirs(dst_path)
for f1 in os.listdir(src_path):
    f1_path = os.path.join(src_path, f1)
    f1_path_dst = os.path.join(dst_path, f1)
    if('xilinx_ip'==f1):                      #复制ip下的xci文件
        for f2 in os.listdir(f1_path):
            f2_path = os.path.join(f1_path, f2)
            f2_path_dst = os.path.join(f1_path_dst, f2)
            if(os.path.isdir(f2_path)):
                os.makedirs(f2_path_dst)
                for f3 in os.listdir(f2_path):
                    f3_path = os.path.join(f2_path, f3)
                    f3_path_dst = os.path.join(f2_path_dst, f3)
                    if f3.split('.')[-1] == 'xci':
                        shutil.copy(f3_path, f3_path_dst)
                        print(f3_path_dst)
    else:
        if(os.path.isdir(f1_path)):
            shutil.copytree(f1_path, f1_path_dst)
            print(f1_path_dst)
        else:
            shutil.copy(f1_path, f1_path_dst)
            print(f1_path_dst)
