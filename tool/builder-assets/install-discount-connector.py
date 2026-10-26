"""Apply reviewed, scoped connector diffs while preserving concurrent server edits."""
from pathlib import Path
import argparse
import difflib
import hashlib
import json
import os
import subprocess


def reconcile(baseline, candidate, current):
    old, new = baseline.splitlines(True), candidate.splitlines(True)
    for group in difflib.SequenceMatcher(None, old, new, autojunk=False).get_grouped_opcodes(5):
        before = ''.join(old[group[0][1]:group[-1][2]])
        after = ''.join(new[group[0][3]:group[-1][4]])
        # Installed pre-directory-review connectors retain the old text domain.
        # Preserve it in existing view blocks rather than rewriting the whole file.
        if before not in current and current.count(before.replace("'mobi2app-connector'", "'mobishop'")) == 1:
            before=before.replace("'mobi2app-connector'", "'mobishop'")
            after=after.replace("'mobi2app-connector'", "'mobishop'")
        if current.count(after) == 1 and before not in current:
            continue
        assert before and current.count(before) == 1, 'Current connector differs at a reviewed change; reconcile first'
        current = current.replace(before, after, 1)
    return current


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('plugin')
    parser.add_argument('package')
    parser.add_argument('backup')
    parser.add_argument('--activate', action='store_true')
    args = parser.parse_args()
    root, package, work = map(lambda p: Path(p).resolve(), (args.plugin,args.package,args.backup))
    assert root.name == 'mobi2app-connector' and root.is_dir()
    sha = lambda value: hashlib.sha256(value).hexdigest()
    if not args.activate:
        assert not work.exists()
        work.mkdir(mode=0o700, parents=True)
        records = {}
        for file in sorted((package/'candidate').rglob('*.php')):
            name = file.relative_to(package/'candidate').as_posix()
            target, base = root/name, package/'baseline'/name
            original = target.read_bytes() if target.exists() else None
            if base.exists():
                assert original is not None, 'Installed file missing: '+name
                changed = reconcile(base.read_text(),file.read_text(),original.decode().replace('\r\n','\n'))
                if b'\r\n' in original: changed=changed.replace('\n','\r\n')
                changed=changed.encode()
            else:
                changed=file.read_bytes()
                assert original is None or original == changed, 'New module already exists with different contents: '+name
            for folder, content in [('original',original),('candidate',changed)]:
                if content is not None:
                    path=work/folder/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(content)
            subprocess.run(['/opt/cpanel/ea-php83/root/usr/bin/php','-l',str(work/'candidate'/name)],check=True)
            records[name]={'original':sha(original) if original is not None else None,'candidate':sha(changed)}
        (work/'manifest.json').write_text(json.dumps({'root':str(root),'files':records},indent=2))
        print(json.dumps({'staged':len(records),'backup':str(work)}))
        return
    record=json.loads((work/'manifest.json').read_text())
    assert record['root']==str(root)
    for name, hashes in record['files'].items():
        target=root/name
        assert (sha(target.read_bytes()) if target.exists() else None)==hashes['original'], 'Concurrent change: '+name
        assert sha((work/'candidate'/name).read_bytes())==hashes['candidate']
    # New modules first, so every newly introduced require resolves during deployment.
    names=sorted(record['files'],key=lambda name:record['files'][name]['original'] is not None)
    owner=root.stat()
    for name in names:
        target=root/name; pending=target.with_name(target.name+'.discounts-tmp')
        with pending.open('xb') as handle: handle.write((work/'candidate'/name).read_bytes())
        os.chown(pending,owner.st_uid,owner.st_gid);os.chmod(pending,0o644);pending.replace(target)
        assert sha(target.read_bytes())==record['files'][name]['candidate']
    print(json.dumps({'activated':len(names),'backup':str(work)}))


if __name__=='__main__':
    main()
