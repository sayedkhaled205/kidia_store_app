import contextlib
import io
from pathlib import Path
import sys
import tempfile
import unittest

from retry_dependency_download import retryable, run

SWIFT = "Could not resolve package dependencies:\nfailed downloading 'https://github.com/facebook/facebook-ios-sdk/releases/download/v18.1.1/FBAEMKit-Dynamic_XCFramework.zip' which is required by binary target 'FBAEMKit': badResponseStatusCode(504)\n"
GRADLE = 'java.io.IOException: Server returned HTTP response code: 504 for URL: https://github.com/gradle/gradle-distributions/releases/download/v9.1.0/gradle-9.1.0-all.zip\n at org.gradle.wrapper.Download.downloadInternal(Download.java:61)\n'


class DownloadRecoveryTests(unittest.TestCase):
    def test_observed_failures_and_fail_closed_cases(self):
        for log in (SWIFT, GRADLE):
            self.assertTrue(retryable(log))
            for code in ('400', '401', '403', '404', '500'):
                self.assertFalse(retryable(log.replace('504', code)))
            self.assertFalse(retryable(log + 'checksum mismatch'))
            self.assertFalse(retryable(log + 'compilation failed'))
        self.assertFalse(retryable('Dart compiler error: 504'))
        self.assertFalse(retryable('Signing failed'))

    def exercise(self, failure, fail_count, expected_runs, expected_exit):
        with tempfile.TemporaryDirectory() as folder:
            counter = Path(folder) / 'count'
            child = Path(folder) / 'child.py'
            child.write_text("from pathlib import Path\nimport sys\np=Path(sys.argv[1])\nn=int(p.read_text())+1 if p.exists() else 1\np.write_text(str(n))\nprint(" + repr(failure) + f" if n <= {fail_count} else 'prepared')\nsys.exit(7 if n <= {fail_count} else 0)\n", encoding='utf-8')
            delays = []
            with contextlib.redirect_stdout(io.StringIO()):
                result = run([sys.executable, str(child), str(counter)], sleep=delays.append)
            self.assertEqual(result, expected_exit)
            self.assertEqual(int(counter.read_text()), expected_runs)
            self.assertEqual(delays, [10, 30][:expected_runs - 1])

    def test_download_recovers_on_second_attempt(self):
        self.exercise(SWIFT, 1, 2, 0)

    def test_download_exhaustion_preserves_failure(self):
        self.exercise(GRADLE, 99, 3, 7)

    def test_non_network_failure_is_not_retried(self):
        self.exercise('Code signing failed', 99, 1, 7)

    def test_mixed_failures_are_not_retried(self):
        for failure in ('Execution failed for task :app:compileReleaseKotlin',
                        'lib/main.dart:3:7: Error: Method not found',
                        'e: file:///app.kt:1: Unresolved reference',
                        'BUILD FAILED', 'Swift Compiler Error',
                        'linker command failed', 'invalid manifest'):
            with self.subTest(failure=failure):
                self.exercise(GRADLE + failure, 99, 1, 7)

    def test_non_network_failure_before_tail_is_not_lost(self):
        self.exercise('BUILD FAILED\n' + 'detail\n' * 600 + GRADLE, 99, 1, 7)

    def test_success_runs_once(self):
        self.exercise('', 0, 1, 0)


if __name__ == '__main__':
    unittest.main()
