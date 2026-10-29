"""Version the report CSS and current frame without replacing concurrent UI code."""
from pathlib import Path
import hashlib,json,os,re,sys
root=Path('/home/woomobile/woomobile-api/public/mobishop-builder-v26')
css=Path(sys.argv[1]).read_bytes();sha=lambda b:hashlib.sha256(b).hexdigest()
version=sha(css)[:12];backup=Path('/home/woomobile/push-report-style-backup-'+version)
index=(root/'index.html').read_bytes();central=re.search(rb'assets/(?:original|customize)-central[^"?\s]+\.js',index).group().decode()
parent=(root/central).read_bytes();frame=re.search(rb'(?:screen-frame|customize-screen-frame)[^"?\s]+\.html',parent).group().decode()
html=(root/frame).read_bytes();old=re.search(rb'assets/push-analytics-[a-f0-9]+\.css',html).group()
new='assets/push-analytics-'+version+'.css';new_frame='screen-frame-push-report-style-'+version+'.html';new_parent='assets/original-central-push-report-style-'+version+'.js'
assert not backup.exists() and html.count(old)==1 and 1<=parent.count(frame.encode())<=10 and 1<=index.count(central.encode())<=4
backup.mkdir(mode=0o700);(backup/'index.old').write_bytes(index)
checks={str(root/'index.html'):sha(index),str(root/central):sha(parent),str(root/frame):sha(html)}
for name,digest in checks.items():assert sha(Path(name).read_bytes())==digest,'Concurrent source changed'
for name,data in {new:css,new_frame:html.replace(old,new.encode()),new_parent:parent.replace(frame.encode(),new_frame.encode())}.items():
    path=root/name;assert not path.exists();owner=path.parent.stat();path.write_bytes(data);os.chmod(path,0o644);os.chown(path,owner.st_uid,owner.st_gid)
for name,digest in checks.items():assert sha(Path(name).read_bytes())==digest,'Concurrent source changed before activation'
after=index.replace(central.encode(),new_parent.encode());temp=root/'index.push-report-tmp';assert not temp.exists()
owner=(root/'index.html').stat();temp.write_bytes(after);os.chmod(temp,0o644);os.chown(temp,owner.st_uid,owner.st_gid)
(backup/'manifest.json').write_text(json.dumps({'checks':checks,'after':sha(after),'rollback':'Restore index.old only if current index matches after'},indent=2))
temp.replace(root/'index.html');print(json.dumps({'activated':True,'backup':str(backup),'frame':new_frame}))
