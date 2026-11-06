"""Root integration in a disposable container only. No host mounts or real secrets."""
import base64
import hashlib
import hmac
import json
import os
from pathlib import Path
import pty
import pwd
import select
import struct
import subprocess
import time
from urllib.parse import parse_qs, urlsplit

PLUGIN = Path('/opt/plugin')
OWNER = 'access-test'
BROKER = '/usr/local/sbin/z13-admin'


def root(*args, check=True):
    return subprocess.run(args, capture_output=True, text=True, check=check)


def owner(*args, check=True):
    account = pwd.getpwnam(OWNER)
    def drop():
        os.setgroups([])
        os.setgid(account.pw_gid)
        os.setuid(account.pw_uid)
    return subprocess.run(['/usr/bin/sudo', '-n', BROKER, *args], preexec_fn=drop,
                          env={'PATH': '/usr/bin:/bin', 'HOME': account.pw_dir},
                          capture_output=True, text=True, check=check)


def otp(secret, counter):
    digest = hmac.digest(base64.b32decode(secret), struct.pack('>Q', counter), 'sha1')
    offset = digest[-1] & 15
    return str((struct.unpack('>I', digest[offset:offset + 4])[0] & 0x7fffffff) % 1000000).zfill(6)


def prompt(args, code):
    pid, fd = pty.fork()
    if pid == 0:
        os.execve(args[0], args, {'PATH': '/usr/bin:/bin', 'SUDO_USER': OWNER, 'HOME': '/root'})
    buffer = b''
    sent = False
    deadline = time.monotonic() + 12
    try:
        while time.monotonic() < deadline:
            readable, _, _ = select.select([fd], [], [], 0.2)
            if readable:
                try:
                    data = os.read(fd, 4096)
                except OSError:
                    break
                if not data:
                    break
                buffer += data
                if not sent and b'code: ' in buffer:
                    # Read-only status must not wait for the live OTP prompt.
                    before = time.monotonic()
                    owner('status')
                    assert time.monotonic() - before < 2
                    os.write(fd, (code() + '\n').encode())
                    sent = True
        else:
            os.kill(pid, 9)
            raise AssertionError('OTP prompt timed out')
    finally:
        os.close(fd)
    _, status = os.waitpid(pid, 0)
    assert sent, 'OTP prompt was not reached'
    return os.waitstatus_to_exitcode(status)


assert os.geteuid() == 0 and Path('/.dockerenv').exists(), 'Container-only test'
root('/bin/bash', str(PLUGIN / 'install-approval.sh'), OWNER)
assert json.loads(owner('status').stdout)['version'] == '2.0.1'

# Capture the generated enrollment URI inside this disposable container only.
# The fixture never prints it and never touches a host credential.
root('/bin/mv', '/usr/bin/qrencode', '/usr/bin/qrencode.real')
Path('/usr/bin/qrencode').write_text('#!/bin/sh\numask 077\ncat > /root/enrollment-uri\n')
Path('/usr/bin/qrencode').chmod(0o755)
def enrollment_code():
    secret = parse_qs(urlsplit(Path('/root/enrollment-uri').read_text()).query)['secret'][0]
    return otp(secret, int(time.time() // 30))
assert prompt([BROKER + '-enroll', 'enroll'], enrollment_code) == 0
auth = Path('/var/lib/z13-admin/auth.json')
assert auth.stat().st_mode & 0o777 == 0o600
original_auth = auth.read_bytes()
secret = json.loads(original_auth)['secret']

# An upgrade must preserve enrollment and replay protection byte for byte.
root('/bin/bash', str(PLUGIN / 'install-approval.sh'), OWNER)
assert auth.read_bytes() == original_auth
request = json.loads(owner('request', '--minutes', '2', '--reason', 'Container fixture').stdout)
code = otp(secret, int(time.time() // 30) + 1)
assert prompt([BROKER, 'approve', request['id']], lambda: code) == 0
first = json.loads(owner('status').stdout)['request']
assert 'uid=0' in owner('run', request['id'], '--', '/usr/bin/id').stdout
owner('run', request['id'], '--', '/usr/bin/true')
second = json.loads(owner('status').stdout)['request']
assert second['runs'] == 2 and second['expires'] == first['expires']
owner('shorten', request['id'], '--minutes', '1')
assert owner('shorten', request['id'], '--minutes', '2', check=False).returncode != 0
owner('revoke')
assert owner('run', request['id'], '--', '/usr/bin/id', check=False).returncode != 0
request = json.loads(owner('request', '--minutes', '1', '--reason', 'Replay fixture').stdout)
assert prompt([BROKER, 'approve', request['id']], lambda: code) != 0
owner('revoke')

# Fail the final policy check, then verify transactional rollback of every file.
paths = [Path('/etc/omarchy-sudo-approval-owner'), Path(BROKER), Path(BROKER + '-enroll'), Path('/etc/sudoers.d/90-z13-admin')]
before = {str(path): hashlib.sha256(path.read_bytes()).digest() for path in paths}
root('/bin/mv', '/usr/sbin/visudo', '/usr/sbin/visudo.real')
Path('/usr/sbin/visudo').write_text('#!/bin/sh\nn=$(cat /tmp/visudo-count 2>/dev/null || echo 0)\nn=$((n+1))\necho "$n" >/tmp/visudo-count\n[ "$n" = 3 ] && exit 1\nexec /usr/sbin/visudo.real "$@"\n')
Path('/usr/sbin/visudo').chmod(0o755)
assert root('/bin/bash', str(PLUGIN / 'install-approval.sh'), OWNER, check=False).returncode != 0
assert all(hashlib.sha256(Path(path).read_bytes()).digest() == digest for path, digest in before.items())
assert json.loads(owner('status').stdout)['enrolled'] is True
print('Fresh install, enrollment, upgrade preservation, multiple commands, shortening, revoke, replay denial, non-blocking status and rollback passed.')
