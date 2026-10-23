import pathlib,shutil,zipfile
root=pathlib.Path('/home/kidiastore/public_html/wp-content/plugins/mobi2app-connector')
patches={
'includes/class-mobishop-setup-wizard.php':[("$layout['header']['settings']['logo_width'] = 100;","$layout['header']['settings']['logo_width'] = 90;"),("$layout['header']['settings']['logo_height'] = 34;","$layout['header']['settings']['logo_height'] = 30.6;"),("$layout['settings']['font_family'] = 'poppins';","$layout['settings']['font_family'] = 'poppins';\n\t\t\t$layout['header']['settings']['auth_logo_scale'] = 0.9;")],
'includes/class-mobishop-page-layout-store.php':[("self::field( 'logo_url',","self::field( 'auth_logo_scale', __( 'Sign-in logo scale', 'mobi2app-connector' ), 'number', 1, array(), 0.5, 1.5 ),\n\t\t\tself::field( 'logo_url',")],
}
def transform(name,data):
 for old,new in patches.get(name,[]):
  if b'\r\n' in data: old=old.replace('\n','\r\n');new=new.replace('\n','\r\n')
  if new.encode() in data: continue
  assert old.encode() in data,name
  data=data.replace(old.encode(),new.encode(),1)
 return data
pending={name:transform(name,(root/name).read_bytes()) for name in patches}
for name,data in pending.items():
 p=root/name;shutil.copy2(p,str(p)+'.before307');p.write_bytes(data)
archive=pathlib.Path('/home/woomobile/public_html/downloads/mobi2app-connector.zip')
shutil.copy2(archive,str(archive)+'.before307')
with zipfile.ZipFile(archive) as z: files={n:z.read(n) for n in z.namelist()}
for n,data in files.items():
 name=n.removeprefix('mobi2app-connector/')
 data=transform(name,data)
 if name in ['mobi2app-connector.php','readme.txt','SOURCE-BUILD.txt']: data=data.replace(b'1.46.84',b'1.46.85')
 files[n]=data
with zipfile.ZipFile(str(archive)+'.new','w',zipfile.ZIP_DEFLATED) as z:
 for n,data in files.items():z.writestr(n,data)
pathlib.Path(str(archive)+'.new').replace(archive)
print('KIDS307 CONNECTOR UPDATED')
