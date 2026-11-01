import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import deploy_customer_registration as deploy


class PublicationRecoveryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.backup = self.root / 'backup'
        self.backup.mkdir()
        changes = {}
        for i, name in enumerate(('auth.php', 'version.php', 'versioned.zip')):
            path = self.root / name
            old, new = b'old-' + str(i).encode(), b'new-' + str(i).encode()
            if i < 2:
                path.write_bytes(old)
                (self.backup / f'{i}.old').write_bytes(old)
            (self.backup / f'{i}.new').write_bytes(new)
            changes[str(path)] = {'number': str(i), 'before': deploy.sha(old) if i < 2 else None, 'after': deploy.sha(new)}
        (self.backup / 'manifest.json').write_text(json.dumps({'changes': changes, 'metadata': {}}))
        self.addCleanup(patch.stopall)
        patch.object(deploy, 'BACKUP', self.backup).start()
        self.writer = patch.object(deploy, 'write', side_effect=lambda p, data: p.write_bytes(data)).start()

    def test_retry_and_rollback_recover_partial_publication(self):
        def interrupted(path, data):
            if path.name == 'version.php':
                raise OSError('simulated interrupted publication')
            path.write_bytes(data)
        self.writer.side_effect = interrupted
        with self.assertRaises(OSError):
            deploy.activate()
        self.assertEqual((self.root / 'auth.php').read_bytes(), b'new-0')
        self.writer.side_effect = lambda p, data: p.write_bytes(data)
        deploy.activate(rollback=True)
        self.assertEqual((self.root / 'auth.php').read_bytes(), b'old-0')
        deploy.activate()
        deploy.activate()
        self.assertEqual((self.root / 'version.php').read_bytes(), b'new-1')
        deploy.activate(rollback=True)
        self.assertEqual((self.root / 'version.php').read_bytes(), b'old-1')
        self.assertEqual((self.root / 'versioned.zip').read_bytes(), b'new-2')

    def test_unrelated_concurrent_change_stops_before_writes(self):
        (self.root / 'version.php').write_bytes(b'another-chat-change')
        with self.assertRaisesRegex(AssertionError, 'Concurrent change'):
            deploy.activate()
        self.writer.assert_not_called()

    def test_tampered_stage_stops_before_writes(self):
        (self.backup / '1.new').write_bytes(b'unreviewed-source')
        with self.assertRaises(AssertionError):
            deploy.activate()
        self.writer.assert_not_called()


if __name__ == '__main__':
    unittest.main()
