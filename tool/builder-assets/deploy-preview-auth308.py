from pathlib import Path
import re, zipfile, hashlib, shutil, datetime, os

root=Path('/home/woomobile/woomobile-api/public/mobishop-builder-v26')
archive=Path('/home/kidiastore/builder288-upload/auth-preview308.zip')
assert hashlib.sha256(archive.read_bytes()).hexdigest()=='b7e5b62af05fca382257b6affb0c0d1b855ec8fcd066bf58e0ead73085566bca'
index=(root/'index.html').read_text()
central=re.search(r'assets/original-central[^"\s]+?\.js',index).group(0)
source=(root/central).read_text()
frame=re.search(r'screen-frame-filter307\.html',source).group(0)
html=(root/frame).read_text()
frame_js=re.search(r'assets/screen-frame-filter307\.js',html).group(0)
frame_source=(root/frame_js).read_text()
old='assets/flutter-preview-filter307/'
new='assets/flutter-preview-auth308/'
assert old in source and old in frame_source
assert 'mobishop-preview-auth-config-request' not in source
marker="    if (message.type !== 'mobishop-preview-catalog-request') return;"
assert source.count(marker)==1
hook="""    if (message.type === 'mobishop-preview-auth-config-request') {
      const requestId = Number(message.request_id);
      if (!Number.isSafeInteger(requestId) || requestId < 1 || !store) return;
      let response;
      try {
        response = await KidiaPreviewAuth.load(await load('home-builder'), window.fetch.bind(window));
      } catch (error) { response = {error: 'Preview authentication settings unavailable.'}; }
      mobileFrame.contentWindow.postMessage(JSON.stringify(Object.assign(response, {
        type: 'mobishop-preview-auth-config-response', request_id: requestId
      })), location.origin);
      return;
    }
"""
target=root/new.rstrip('/')
assert not target.exists()
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    for name in z.namelist(): assert target.resolve() in (target/name).resolve().parents
    helper=z.read('preview-auth-config.js').decode()
    source=helper+'\n'+source.replace(marker,hook+marker).replace(old,new)
    z.extractall(target)
new_frame='screen-frame-auth308.html'
new_js='assets/screen-frame-auth308.js'
new_central='assets/original-central-auth308.js'
source=source.replace(frame,new_frame)
html=html.replace(frame_js,new_js)
html=re.sub('('+re.escape(new_js)+r')(?:\?[^"\']*)?',lambda m:m[1]+'?v=auth308',html)
frame_source=frame_source.replace(old,new)
index=re.sub('('+re.escape(central)+r')(?:\?[^"\']*)?',lambda m:new_central+'?v=auth308',index)
changes={new_central:source,new_js:frame_source,new_frame:html,'index.html':index}
backup=root.parent.parent/('auth-preview-backup-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
backup.mkdir(mode=0o700)
st=(root/'index.html').stat()
for p in [target,*target.rglob('*')]:
    os.chown(p,st.st_uid,st.st_gid);os.chmod(p,0o755 if p.is_dir() else 0o644)
for name,data in changes.items():
    path=root/name
    saved=backup/name;saved.parent.mkdir(parents=True,exist_ok=True)
    if path.exists():shutil.copy2(path,saved)
    temp=path.with_name(path.name+'.auth-tmp');temp.write_text(data)
    os.chown(temp,st.st_uid,st.st_gid);os.chmod(temp,0o644);temp.replace(path)
print('AUTH_PREVIEW_DEPLOYED',new,'backup',backup)
