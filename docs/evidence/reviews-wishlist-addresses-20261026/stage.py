from pathlib import Path
import hashlib,subprocess,copy,zipfile
remote=Path('/root/review-wishlist-addresses-20261026');remote.mkdir(exist_ok=True)
prefix='https://raw.githubusercontent.com/sayedkhaled205/kidia_store_app/a025928966aec9aa0eb1ac95ada66c7d5c134704/'
def download(name,sha):
 data=subprocess.check_output(['curl','--fail','--silent','--show-error','--max-time','90',prefix+name])
 assert hashlib.sha256(data).hexdigest()==sha,name
 return data
for name,(source,sha) in {'publish-preview-runtime.py': ('tool/builder-assets/publish-preview-runtime.py', 'c66146e792ad7616a445729f3671353803048ff1a343ca929c6be38dcf128ab0'), 'repair-preview-contracts.py': ('tool/builder-assets/repair-preview-contracts.py', 'bd6937aa641a068dca69d4e0dba1242a6c7ba9c26d4c10bac360e08206d3c386'), 'preview-commerce-config.js': ('tool/builder-assets/preview-commerce-config.js', '0cb014daf9d80aa8d30dc0a21df1343aafb45ae47ccf03b7a23ad78cda196169'), 'preview-interactions.js': ('tool/builder-assets/preview-interactions.js', 'f3c591d8cb5d004d1ce081a92d98db88143589653c444801524ef9899673db4a'), 'category-designer.js': ('tool/builder-assets/category-designer.js', 'e15bda8cfe476caa25bdceb95ba8dfaa930ed5dfecd4ea5726f1d5b693f309cd')}.items(): (remote/name).write_bytes(download(source,sha))
updates={name:download('mobishop/admin/flutter-preview/'+name,sha) for name,sha in {'main.dart.js': 'b6d9056ae9359ef23c582d891f22541d5368b0043a317e629a2c9c9ae7ff2b1c', 'assets/fonts/MaterialIcons-Regular.otf': 'd8e062a05eb3e03650286714a882a9ce1b29676e0393cd6d634b0f59d7310813'}.items()}
base=Path('/home/kidiastore/builder288-upload/category-expanded-designs-20261026.zip')
archive=base.with_name('review-wishlist-addresses-20261026.zip')
assert not archive.exists()
with zipfile.ZipFile(base) as old:
 assert hashlib.sha256(old.read('main.dart.js')).hexdigest()=='e483b5a5a5baae42c513d98fff10e388eb57b2c35e8d2c583a8882239d3877d5'
 with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as new:
  for item in old.infolist(): new.writestr(copy.copy(item),updates.get(item.filename,old.read(item.filename)))
 with zipfile.ZipFile(archive) as new:
  assert new.testzip() is None
  for name in old.namelist(): assert new.read(name)==updates.get(name,old.read(name))
command=['python3',str(remote/'publish-preview-runtime.py'),'/home/woomobile/woomobile-api/public/mobishop-builder-v26',str(archive),str(remote/'preview-interactions.js'),hashlib.sha256(archive.read_bytes()).hexdigest()]
(remote/'activate.txt').write_text(' '.join(command)+' --activate')
subprocess.run(command,check=True)
