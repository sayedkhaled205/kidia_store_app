"""Publish only an independently verified, existing store IPA; never rebuild it."""
import hashlib
import os
from pathlib import Path
import plistlib
import re
import shutil
import tempfile
from urllib.parse import urlsplit
from urllib.request import urlopen
import zipfile

from verify_ios_signing import SigningError, identity, verify_ipa


def prepare(environment, output, opener=urlopen, verifier=verify_ipa):
    # Only this path is collected by the upload workflow. Failed checks cannot
    # leave an old publishable IPA behind, even if a runner restores its cache.
    output.unlink(missing_ok=True)
    expected = identity(environment)
    url = environment.get('SIGNED_IPA_URL', '')
    parsed = urlsplit(url)
    checksum = environment.get('SIGNED_IPA_SHA256', '')
    version = environment.get('BUILD_VERSION_CODE', '')
    if (parsed.scheme != 'https' or parsed.hostname != 'api.codemagic.io'
            or parsed.username or parsed.password or parsed.port not in (None, 443)
            or not re.fullmatch(r'[a-f0-9]{64}', checksum)
            or not re.fullmatch(r'[1-9][0-9]*', version)):
        raise SigningError('A pinned Codemagic IPA and expected build number are required.')
    with tempfile.TemporaryDirectory(prefix='mobishop-upload-') as directory:
        candidate = Path(directory) / 'app.ipa'
        digest = hashlib.sha256()
        total = 0
        with opener(url, timeout=60) as response, candidate.open('wb') as target:
            while chunk := response.read(1024 * 1024):
                total += len(chunk)
                if total > 512 * 1024 * 1024:
                    raise SigningError('The application artifact exceeds the upload limit.')
                target.write(chunk)
                digest.update(chunk)
        if digest.hexdigest() != checksum:
            raise SigningError('The application artifact differs from the verified build.')
        with zipfile.ZipFile(candidate) as archive:
            names = [n for n in archive.namelist()
                     if re.fullmatch(r'Payload/[^/]+\.app/Info\.plist', n)]
            if len(names) != 1 or archive.getinfo(names[0]).file_size > 1024 * 1024:
                raise SigningError('The artifact must contain exactly one application identity.')
            info = plistlib.loads(archive.read(names[0]))
        if (info.get('CFBundleIdentifier') != expected['bundle']
                or str(info.get('CFBundleVersion')) != version
                or info.get('CFBundleShortVersionString') != environment.get('BUILD_VERSION_NAME')):
            raise SigningError('The application identity or version differs from the requested upload.')
        verifier(candidate, environment)
        output.parent.mkdir(parents=True, exist_ok=True)
        # Do not expose an upload artifact until signature and merchant checks pass.
        staged = output.with_suffix('.pending')
        shutil.copyfile(candidate, staged)
        staged.replace(output)
    print('Existing signed application verified for App Store Connect upload.')


if __name__ == '__main__':
    try:
        prepare(os.environ, Path('build/verified-testflight/app.ipa'))
    except Exception:
        # Provider download URLs can contain temporary credentials; never echo them.
        raise SystemExit('The existing application could not be verified for upload.') from None
