import hashlib, os, shutil
src_dir = '/tmp/o252_out/'
dst_dir = '/workspace/30_output_share/'
for name in sorted(os.listdir(src_dir)):
    src, dst = src_dir + name, dst_dir + name
    with open(src, 'rb') as fh:
        data = fh.read()
    with open(dst, 'wb') as fh:
        fh.write(data)
    with open(dst, 'rb') as fh:
        back = fh.read()
    print(name, len(data), hashlib.sha256(data).hexdigest()[:12], hashlib.sha256(back).hexdigest()[:12])
