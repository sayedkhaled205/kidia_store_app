"""Keep the shared Kids preset dimensions aligned with the artwork renderer."""
import json, pathlib, re, shutil
root=pathlib.Path('/home/woomobile/woomobile-api/public/mobishop-builder-v26')
index=(root/'index.html').read_text()
parent=re.search(r'assets/((?:original|customize)-central[^"?]+\.js)',index).group(1)
source=(root/'assets'/parent).read_text()
name=re.search(r"assets/(theme-snapshots[^\"?']+\.json)",source).group(1)
path=root/'assets'/name
shutil.copy2(path,str(path)+'.before-kids306')
data=json.loads(path.read_text())
h=data['kids_baby']['pages']['home']['header']['settings']
h.update(logo_width=100,logo_height=34,logo_fit='contain')
new='theme-snapshots-kids-v306.json'
(root/'assets'/new).write_text(json.dumps(data,ensure_ascii=False))
for script in (root/'assets').glob('*.js'):
 text=script.read_text()
 if name in text:
  shutil.copy2(script,str(script)+'.before-kids306')
  script.write_text(text.replace(name,new))
source=(root/'assets'/parent).read_text()
frame=re.search(r'((?:screen-frame|customize-screen-frame)[^"?\s]+\.html)',source).group(1)
frame_html=(root/frame).read_text()
script=re.search(r'assets/((?:screen-frame|customize-screen-frame)[^"?]+\.js)',frame_html).group(1)
(root/'assets'/'screen-frame-kids306.js').write_text((root/'assets'/script).read_text())
(root/'screen-frame-kids306.html').write_text(frame_html.replace(script,'screen-frame-kids306.js'))
(root/'assets'/'original-central-kids306.js').write_text(source.replace(frame,'screen-frame-kids306.html'))
shutil.copy2(root/'index.html',root/'index.html.before-kids306')
(root/'index.html').write_text(index.replace(parent,'original-central-kids306.js'))
print('SHARED_KIDS_PRESET_306')
