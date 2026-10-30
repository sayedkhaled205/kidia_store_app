"""One isolated, expiring store release. Never prints credentials or provider output."""
import json, os, pathlib, plistlib, re, subprocess, tempfile, urllib.parse, urllib.request, zipfile
import xml.etree.ElementTree as ET

API_ORIGIN = 'https://api.woomobile.app/v1/store-publication-runner'
MAX_BYTES = 1500 * 1024 * 1024

def approved_download(url):
    p = urllib.parse.urlsplit(url)
    host = p.hostname or ''
    if p.scheme != 'https' or p.username or p.password or p.port not in (None, 443):
        raise ValueError('Untrusted artifact origin')
    # Codemagic artifact links redirect to this Google Storage bucket. Keep the
    # signed query untouched and allow only literal paths inside that bucket.
    google_artifact = (
        host == 'storage.googleapis.com'
        and re.fullmatch(r'/codemagic-build-artifacts/[A-Za-z0-9_./-]+', p.path)
        and all(part not in ('', '.', '..') for part in p.path.split('/')[2:])
    )
    if not (host == 'api.codemagic.io' or host.endswith('.codemagic.io')
            or host.endswith('.amazonaws.com') or google_artifact):
        raise ValueError('Untrusted artifact origin')
    return url

class ArtifactRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        approved_download(newurl)
        return super().redirect_request(req, fp, code, msg, headers, newurl)

def artifact_from_archive(archive, platform, directory):
    extension = '.aab' if platform == 'android' else '.ipa'
    with zipfile.ZipFile(archive) as bundle:
        matches = [i for i in bundle.infolist() if i.filename.lower().endswith(extension) and not i.is_dir()]
        if len(matches) != 1 or matches[0].file_size > MAX_BYTES:
            raise ValueError('Expected exactly one bounded artifact')
        target = directory / ('application' + extension)
        with bundle.open(matches[0]) as source, target.open('wb') as output:
            total = 0
            while chunk := source.read(1024 * 1024):
                total += len(chunk)
                if total > MAX_BYTES: raise ValueError('Artifact too large')
                output.write(chunk)
        return target

def run_capture(command, env=None, timeout=180):
    result = subprocess.run(command, env=env, capture_output=True, timeout=timeout)
    if result.returncode: raise RuntimeError('Provider command did not confirm success')
    return result.stdout.decode('utf-8')

def validate_identity(artifact, payload):
    if payload['platform'] == 'android':
        manifest = ET.fromstring(run_capture(['android-app-bundle', 'dump', 'manifest', '--bundle', str(artifact)]))
        android = '{http://schemas.android.com/apk/res/android}'
        actual = (manifest.attrib.get('package'), manifest.attrib.get(android+'versionName'), manifest.attrib.get(android+'versionCode'))
    else:
        with zipfile.ZipFile(artifact) as ipa:
            names = [n for n in ipa.namelist() if re.fullmatch(r'Payload/[^/]+\.app/Info\.plist', n)]
            if len(names) != 1 or ipa.getinfo(names[0]).file_size > 1024*1024: raise ValueError('Invalid IPA identity')
            info = plistlib.loads(ipa.read(names[0]))
        actual = (info.get('CFBundleIdentifier'), info.get('CFBundleShortVersionString'), str(info.get('CFBundleVersion')))
    expected = (payload['application_id'], payload['version'], str(payload['version_code']))
    if actual != expected: raise ValueError('Artifact belongs to a different app or version')

def publish_command(payload, artifact, directory):
    env = os.environ.copy()
    # Do not pass the runner capability to child publishing tools.
    env.pop('PUBLICATION_TOKEN', None)
    if payload['platform'] == 'android':
        key = directory / 'google.json'
        key.write_text(json.dumps(payload['credentials']), encoding='utf-8'); key.chmod(0o600)
        env['GOOGLE_PLAY_SERVICE_ACCOUNT_CREDENTIALS'] = '@file:' + str(key)
        env['GOOGLE_PLAY_RELEASE_NOTES'] = json.dumps([{'language':'en-US','text':payload['notes']}])
        command = ['google-play','bundles','publish','--bundle',str(artifact),'--track',
                   'production' if payload['destination']=='production' else 'internal']
    else:
        key = directory / 'apple.p8'
        key.write_text(payload['credentials']['private_key'],encoding='utf-8');key.chmod(0o600)
        env.update(APP_STORE_CONNECT_ISSUER_ID=payload['credentials']['issuer_id'],
                   APP_STORE_CONNECT_KEY_IDENTIFIER=payload['credentials']['key_id'],
                   APP_STORE_CONNECT_PRIVATE_KEY='@file:'+str(key))
        command = ['app-store-connect','publish','--path',str(artifact),'--enable-package-validation']
        if payload['destination']=='production':
            command += ['--app-store','--release-type','AFTER_APPROVAL','--version-string',payload['version'],'--whats-new',payload['notes']]
        # Plain upload makes the build available for internal TestFlight processing; no external beta submission.
    return command, env

def main():
    token = os.environ['PUBLICATION_TOKEN']; release = os.environ['PUBLICATION_ID']
    if os.environ.get('PUBLICATION_API') != API_ORIGIN or not re.fullmatch(r'[a-zA-Z0-9]{64}',token) or not re.fullmatch(r'[0-9a-f-]{36}',release):
        raise ValueError('Invalid release capability')
    def api(action, body=None):
        req = urllib.request.Request(API_ORIGIN+'/'+release+'/'+action,
            data=json.dumps(body).encode() if body is not None else None,
            headers={'Authorization':'Bearer '+token,'Accept':'application/json','Content-Type':'application/json'})
        # The API capability must never follow a redirect to another destination.
        class NoRedirect(urllib.request.HTTPRedirectHandler):
            def redirect_request(self,*args,**kwargs): raise ValueError('API redirect rejected')
        with urllib.request.build_opener(NoRedirect()).open(req,timeout=60) as response:
            return json.load(response)
    claimed = False
    try:
        payload=api('payload');claimed=True
        if payload.get('schema') != 1 or payload.get('platform') not in ('android','ios') or payload.get('destination') not in ('test','production'):
            raise ValueError('Invalid publication payload')
        with tempfile.TemporaryDirectory(prefix='woomobile-publication-') as temp:
            directory=pathlib.Path(temp);archive=directory/'build.zip'
            with urllib.request.build_opener(ArtifactRedirect()).open(approved_download(payload['download_url']),timeout=90) as source, archive.open('wb') as out:
                total=0
                while chunk:=source.read(1024*1024):
                    total+=len(chunk)
                    if total>MAX_BYTES: raise ValueError('Download too large')
                    out.write(chunk)
            artifact=artifact_from_archive(archive,payload['platform'],directory)
            validate_identity(artifact,payload)
            command,env=publish_command(payload,artifact,directory)
            run_capture(command,env,timeout=5400)
        api('result',{'result':'uploaded'})
        print('Store upload confirmed; review and availability remain controlled by the store.')
    except Exception:
        if claimed:
            try: api('result',{'result':'failed'})
            except Exception: pass
        print('Release not confirmed. Check store state before retrying. Sensitive provider output was withheld.')
        return 1
    return 0

if __name__=='__main__':
    try: raise SystemExit(main())
    except Exception:
        print('Publication setup is incomplete.');raise SystemExit(1)

