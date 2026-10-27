"""Stage and atomically install the authenticated discount proxy route."""
from pathlib import Path
import hashlib
import json
import os
import re
import subprocess
import sys

root=Path(sys.argv[1]).resolve()
source=Path(__file__).parent/'DiscountRulesController.php'
backup=Path(sys.argv[2]).resolve()
assert root.name=='woomobile-api'
php='/opt/cpanel/ea-php83/root/usr/bin/php'
sha=lambda data:hashlib.sha256(data).hexdigest()
names=['routes/web.php','app/Http/Controllers/Portal/DiscountRulesController.php']
if '--activate' not in sys.argv:
    assert not backup.exists()
    backup.mkdir(mode=0o700)
    routes=(root/names[0]).read_text()
    lines=routes.splitlines(keepends=True)
    anchors=[i for i,line in enumerate(lines) if "Route::get('/builder/commerce'," in line and 'StoreDataController' in line]
    assert len(anchors)==1 and '/builder/discount-rules' not in routes
    i=anchors[0]
    indent=re.match(r'\s*',lines[i]).group()
    lines.insert(i+1,indent+"Route::match(['get','post'], '/builder/discount-rules', [\\App\\Http\\Controllers\\Portal\\DiscountRulesController::class, 'handle'])->name('portal.builder.discount-rules');\n")
    changed={names[0]:''.join(lines).encode(),names[1]:source.read_bytes()}
    record={}
    for name,data in changed.items():
        target=root/name; original=target.read_bytes() if target.exists() else None
        if name==names[1]: assert original is None or original==data, 'Existing controller differs; reconcile first'
        for folder,value in [('original',original),('candidate',data)]:
            if value is not None:
                path=backup/folder/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(value)
        subprocess.run([php,'-l',str(backup/'candidate'/name)],check=True)
        record[name]={'original':sha(original) if original is not None else None,'candidate':sha(data)}
    (backup/'manifest.json').write_text(json.dumps(record,indent=2))
    print(json.dumps({'staged':True,'backup':str(backup)}))
else:
    record=json.loads((backup/'manifest.json').read_text())
    for name,digests in record.items():
        target=root/name
        assert (sha(target.read_bytes()) if target.exists() else None)==digests['original'],'Concurrent change: '+name
        assert sha((backup/'candidate'/name).read_bytes())==digests['candidate']
    for name in reversed(names):
        target=root/name; owner=(root/'routes/web.php').stat();temp=target.with_name(target.name+'.discounts-tmp')
        with temp.open('xb') as f:f.write((backup/'candidate'/name).read_bytes())
        os.chown(temp,owner.st_uid,owner.st_gid);os.chmod(temp,0o644);temp.replace(target)
    subprocess.run([php,'artisan','route:clear'],cwd=root,check=True)
    print(json.dumps({'activated':True,'backup':str(backup)}))
