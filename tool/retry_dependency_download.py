"""Retry only transient dependency-download failures in preparation commands."""
from collections import deque
import re
import subprocess
import sys
import time


def non_download_failure(output):
    return bool(re.search(
        r'checksum|certificate|authentication|permission denied|requires .*version|'
        r'conflicting|compilation failed|signing.*failed|Execution failed for task|'
        r'BUILD FAILED|:app:compile|> Task .*compile|\.dart:\d+:\d+: Error:|'
        r'^e: |Swift Compiler Error|linker command failed|invalid manifest',
        output, re.I | re.M))


def retryable(output):
    # A mixed/non-network failure must not be hidden by an earlier HTTP error.
    if non_download_failure(output):
        return False
    swift = ('Could not resolve package dependencies' in output and
             re.search(r"failed downloading 'https://[^\s']+'[^\n]*badResponseStatusCode\(50[234]\)", output))
    gradle = ('org.gradle.wrapper.' in output and
              re.search(r'Server returned HTTP response code: 50[234] for URL: https://[^\s]+/gradle-[^\s]+\.zip', output))
    return bool(swift or gradle)


def run(command, sleep=time.sleep):
    for attempt in range(3):
        tail = deque(maxlen=500)
        blocked = False
        with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              text=True, encoding='utf-8', errors='replace') as process:
            for line in process.stdout:
                print(line, end='', flush=True)
                tail.append(line)
                blocked = blocked or non_download_failure(line)
            result = process.wait()
        if result == 0 or result < 0 or blocked or attempt == 2 or not retryable(''.join(tail)):
            return result if result >= 0 else 128 - result
        delay = (10, 30)[attempt]
        print(f'Transient dependency download failed; preparation retry {attempt + 1}/2 in {delay}s.', flush=True)
        sleep(delay)
    raise AssertionError('unreachable')


if __name__ == '__main__':
    command = sys.argv[1:]
    if command[:1] == ['--']:
        command = command[1:]
    if not command:
        raise SystemExit('A dependency preparation command is required')
    raise SystemExit(run(command))
