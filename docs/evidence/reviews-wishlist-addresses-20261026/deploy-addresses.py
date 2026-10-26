from pathlib import Path
import subprocess,hashlib,os,json
remote=Path('/root/review-wishlist-addresses-20261026/address-adapter')
remote.mkdir(exist_ok=True,parents=True)
prefix='https://raw.githubusercontent.com/sayedkhaled205/kidia_store_app/a025928966aec9aa0eb1ac95ada66c7d5c134704/'
files={'integrations/woocommerce/kidia-address-book.php': '0c2a178f64586ea3f39becd7634f488ee42b8ccbf6e53aec1ef87c9ffa2af038', 'tool/tests/kidia-address-book-test.php': '57490c959097dc02d006b537fdd1da2839a6485ece749e98f299bc31a26c4b08'}
for name,sha in files.items():
 data=subprocess.check_output(['curl','--fail','--silent','--show-error','--max-time','90',prefix+name])
 assert hashlib.sha256(data).hexdigest()==sha
 target=remote/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
 subprocess.run(['php','-l',str(target)],check=True)
subprocess.run(['php',str(remote/'tool/tests/kidia-address-book-test.php')],check=True)
source=Path('/home/kidiastore/public_html/wp-content/plugins/kidia-login-page/includes/class-kidia-shipping-addresses.php')
assert hashlib.sha256(source.read_bytes()).hexdigest()=='884bc69a449f6da7c0aa6edfd607710453e2b327616d56807bf4dbe2612b0695','Website address-book contract changed'
target=Path('/home/kidiastore/public_html/wp-content/mu-plugins/mobi2app-kidia-address-book.php')
data=(remote/'integrations/woocommerce/kidia-address-book.php').read_bytes()
assert not target.exists() or target.read_bytes()==data,'Existing adapter changed'
if not target.exists():
 tmp=target.with_name(target.name+'.staged');assert not tmp.exists()
 tmp.write_bytes(data);owner=target.parent.stat();os.chown(tmp,owner.st_uid,owner.st_gid);os.chmod(tmp,0o644);tmp.replace(target)
print(json.dumps({'address_adapter':'deployed','sha256':hashlib.sha256(data).hexdigest(),'website_source':'verified v1','writes_customer_data':False}))
