"""Synthetic approval tests. Never invokes sudo, real enrollment, root commands or reboot."""
import base64
import importlib.machinery
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

loader = importlib.machinery.SourceFileLoader('broker', str(Path(__file__).with_name('z13-admin')))
spec = importlib.util.spec_from_loader(loader.name, loader)
broker = importlib.util.module_from_spec(spec)
loader.exec_module(broker)
SECRET = base64.b32encode(b'12345678901234567890').decode()


class ApprovalTests(unittest.TestCase):
    def test_rfc6238_sha1_vectors(self):
        for timestamp, expected in [(59, '94287082'), (1111111109, '07081804'),
                                    (1111111111, '14050471'), (1234567890, '89005924'),
                                    (2000000000, '69279037'), (20000000000, '65353130')]:
            self.assertEqual(broker.totp(SECRET, timestamp // 30, 8), expected)

    def test_code_is_single_use(self):
        code = broker.totp(SECRET, 100)
        self.assertEqual(broker.matching_counter(SECRET, code, 3000, 99), 100)
        self.assertIsNone(broker.matching_counter(SECRET, code, 3000, 100))

    def test_code_window_and_bad_format(self):
        self.assertEqual(broker.matching_counter(SECRET, broker.totp(SECRET, 99), 3000, 98), 99)
        self.assertIsNone(broker.matching_counter(SECRET, broker.totp(SECRET, 98), 3000, 0))
        for code in ('', '123', 'abcdef', '1234567', '１２３４５６'):
            self.assertIsNone(broker.matching_counter(SECRET, code, 3000, -1))

    def test_expiry_reboot_and_missing(self):
        value = {'boot': 'a', 'expires': 200}
        self.assertTrue(broker.live(value, 199, 'a'))
        self.assertFalse(broker.live(value, 200, 'a'))
        self.assertFalse(broker.live(value, 100, 'b'))
        self.assertFalse(broker.live(None, 100, 'a'))

    def test_no_wrong_pending_consumed_or_revoked_execution(self):
        for state in ('pending', 'consumed', 'revoked'):
            with self.assertRaises(ValueError):
                broker.consume({'id': 'x', 'boot': 'a', 'expires': 200, 'state': state}, 'x', 100, 'a')
        value = {'id': 'x', 'boot': 'a', 'expires': 200, 'state': 'approved'}
        with self.assertRaises(ValueError):
            broker.consume(value, 'other', 100, 'a')
        with self.assertRaises(ValueError):
            broker.consume(value, 'x', 200, 'a')
        self.assertEqual(broker.consume(value, 'x', 100, 'a')['state'], 'consumed')

    def test_absolute_executable_and_argument_validation(self):
        for argv in ([], ['true'], ['/usr/bin/true', 'hidden\nargument'],
                     ['/usr/bin/true', 'disguised\u202eargument']):
            with self.assertRaises(ValueError):
                broker.validate_argv(argv)
        self.assertEqual(broker.validate_argv(['/usr/bin/true']), [str(Path('/usr/bin/true').resolve())])

    def test_user_owned_executable_denied(self):
        with tempfile.TemporaryDirectory() as directory:
            executable = Path(directory) / 'unsafe'
            executable.write_text('#!/bin/sh\ntrue\n')
            executable.chmod(0o755)
            with self.assertRaises(ValueError):
                broker.validate_argv([str(executable)])

    def test_nonroot_entry_denied(self):
        with patch.object(broker.os, 'geteuid', return_value=1000):
            with self.assertRaisesRegex(ValueError, 'Run through'):
                broker.main()

    def test_enrollment_alias_cannot_bypass_password_protected_entry(self):
        with tempfile.TemporaryDirectory() as directory:
            alias = Path(directory) / 'z13-admin-enroll'
            alias.symlink_to(Path(__file__).with_name('z13-admin').resolve())
            with patch.object(broker.os, 'geteuid', return_value=0), \
                 patch.object(broker, 'configured_owner', return_value='gustav'), \
                 patch.dict(broker.os.environ, {'SUDO_USER': 'gustav'}), \
                 patch.object(broker.sys, 'argv', [str(alias), 'enroll']), \
                 patch.object(broker, 'enroll') as enroll:
                with self.assertRaisesRegex(ValueError, 'separate password-protected'):
                    broker.main()
                enroll.assert_not_called()

    def test_code_entry_timeout_handler_fails_and_clears_timer(self):
        def timeout(_prompt):
            handler = broker.signal.signal.call_args.args[1]
            handler(None, None)
        with patch.object(broker.signal, 'signal', return_value=broker.signal.SIG_DFL), \
             patch.object(broker.signal, 'alarm') as alarm, \
             patch.object(broker.getpass, 'getpass', side_effect=timeout):
            with self.assertRaisesRegex(ValueError, 'timed out'):
                broker.phone_code('fixture', 1)
            self.assertEqual(alarm.call_args_list[-1].args, (0,))


class FlowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.private = Path(self.temp.name) / 'private'
        self.runtime = Path(self.temp.name) / 'runtime'
        # Only the fixture owns user directories. Production still requires root ownership.
        def fixture_directory(path):
            path.mkdir(mode=0o700, exist_ok=True)
        self.patches = [patch.object(broker, 'PRIVATE', self.private),
                        patch.object(broker, 'RUNTIME', self.runtime),
                        patch.object(broker, 'private_directory', fixture_directory),
                        patch.object(broker, 'boot_id', return_value='fixture-boot'),
                        patch.object(broker, 'boottime', return_value=1000.0),
                        patch.object(broker.time, 'time', return_value=3000.0),
                        patch.object(broker, 'audit'), patch('builtins.print')]
        for item in self.patches:
            item.start()
        self.private.mkdir()
        broker.atomic_json(self.private / 'auth.json', {'secret': SECRET, 'last_counter': 90,
                           'failures': 0, 'rate_boot': 'fixture-boot', 'blocked_until': 0})

    def tearDown(self):
        for item in reversed(self.patches):
            item.stop()
        self.temp.cleanup()

    def make_request(self, minutes=5, window=False):
        broker.request(SimpleNamespace(argv=[] if window else ['--', '/usr/bin/true'], reason='fixture diagnostics', minutes=minutes))
        return json.loads((self.runtime / 'request.json').read_text())

    def approve(self, value, code=None):
        with patch.object(broker.sys.stdin, 'isatty', return_value=True), \
             patch.object(broker.getpass, 'getpass', return_value=code or broker.totp(SECRET, 100)):
            broker.approve(SimpleNamespace(id=value['id']))

    def test_request_approve_execute_once(self):
        value = self.make_request()
        self.approve(value)
        with patch.object(broker.os, 'chdir'), patch.object(broker.os, 'execve') as execute:
            broker.run_request(SimpleNamespace(id=value['id']))
            self.assertEqual(execute.call_args.args[1], [str(Path('/usr/bin/true').resolve())])
            self.assertEqual(execute.call_args.args[2]['HOME'], '/root')
            with self.assertRaises(ValueError):
                broker.run_request(SimpleNamespace(id=value['id']))
            self.assertEqual(execute.call_count, 1)

    def test_duration_cap_and_pending_replacement(self):
        for minutes in (0, -1, 16, 9999):
            with self.assertRaises(ValueError):
                self.make_request(minutes)
        self.make_request(15)
        with self.assertRaises(ValueError):
            self.make_request()

    def test_five_bad_codes_lock_out(self):
        value = self.make_request()
        bad = next(str(n).zfill(6) for n in range(100) if broker.matching_counter(SECRET, str(n).zfill(6), 3000, 90) is None)
        for _ in range(5):
            with self.assertRaises(ValueError):
                self.approve(value, bad)
        with self.assertRaisesRegex(ValueError, 'Too many'):
            self.approve(value)

    def test_otp_replay_denied_on_new_request(self):
        value = self.make_request()
        self.approve(value)
        broker.revoke(None)
        next_value = self.make_request()
        with self.assertRaisesRegex(ValueError, 'already used'):
            self.approve(next_value)

    def test_no_approval_after_pending_expiry(self):
        value = self.make_request()
        with patch.object(broker, 'boottime', return_value=1300):
            with self.assertRaisesRegex(ValueError, 'No matching'):
                self.approve(value)

    def test_missing_enrollment_and_nonterminal_denied(self):
        value = self.make_request()
        with patch.object(broker.sys.stdin, 'isatty', return_value=False):
            with self.assertRaisesRegex(ValueError, 'terminal'):
                broker.approve(SimpleNamespace(id=value['id']))
        broker.revoke(None)
        (self.private / 'auth.json').unlink()
        with self.assertRaisesRegex(ValueError, 'enrollment'):
            self.make_request()

    def test_atomic_files_are_private(self):
        value = self.make_request()
        self.assertEqual((self.runtime / 'request.json').stat().st_mode & 0o777, 0o600)
        self.assertEqual(value['state'], 'pending')

    def test_status_does_not_wait_for_approval_write_lock(self):
        self.make_request(window=True)
        with patch.object(broker, 'locked', side_effect=AssertionError('Status must not take write lock')):
            broker.status(None)

    def test_window_runs_multiple_commands_without_moving_expiry(self):
        value = self.make_request(window=True)
        self.approve(value)
        path = self.runtime / 'request.json'
        expires = json.loads(path.read_text())['expires']
        with patch.object(broker.os, 'chdir'), patch.object(broker.os, 'execve') as execute:
            for argv in (['--', '/usr/bin/true'], ['--', '/usr/bin/id']):
                broker.run_request(SimpleNamespace(id=value['id'], argv=argv))
            self.assertEqual(execute.call_count, 2)
        result = json.loads(path.read_text())
        self.assertEqual(result['state'], 'approved')
        self.assertEqual(result['runs'], 2)
        self.assertEqual(result['expires'], expires)

    def test_window_requires_approval_and_a_command(self):
        value = self.make_request(window=True)
        with self.assertRaises(ValueError):
            broker.run_request(SimpleNamespace(id=value['id'], argv=['/usr/bin/id']))
        self.approve(value)
        with self.assertRaises(ValueError):
            broker.run_request(SimpleNamespace(id=value['id'], argv=[]))

    def test_expired_window_cannot_start_another_command(self):
        value = self.make_request(minutes=1, window=True)
        self.approve(value)
        with patch.object(broker, 'boottime', return_value=1060), patch.object(broker.os, 'execve') as execute:
            with self.assertRaises(ValueError):
                broker.run_request(SimpleNamespace(id=value['id'], argv=['/usr/bin/id']))
            execute.assert_not_called()

    def test_revoke_closes_window(self):
        value = self.make_request(window=True)
        self.approve(value)
        broker.revoke(None)
        with self.assertRaises(ValueError):
            broker.run_request(SimpleNamespace(id=value['id'], argv=['/usr/bin/id']))

    def test_shorten_never_extends_or_resets_clock(self):
        value = self.make_request(minutes=10, window=True)
        self.approve(value)
        broker.shorten(SimpleNamespace(id=value['id'], minutes=2))
        path = self.runtime / 'request.json'
        self.assertEqual(json.loads(path.read_text())['expires'], 1120)
        with patch.object(broker, 'boottime', return_value=1100):
            broker.shorten(SimpleNamespace(id=value['id'], minutes=2))
            self.assertEqual(json.loads(path.read_text())['expires'], 1120)
            with self.assertRaisesRegex(ValueError, 'Cannot extend'):
                broker.shorten(SimpleNamespace(id=value['id'], minutes=3))

    def test_owner_can_reduce_duration_at_approval(self):
        value = self.make_request(minutes=10, window=True)
        with patch.object(broker.sys.stdin, 'isatty', return_value=True), \
             patch.object(broker.getpass, 'getpass', return_value=broker.totp(SECRET, 100)):
            broker.approve(SimpleNamespace(id=value['id'], minutes=3))
        self.assertEqual(json.loads((self.runtime / 'request.json').read_text())['expires'], 1180)

    def test_approval_cannot_increase_duration(self):
        value = self.make_request(minutes=1, window=True)
        with self.assertRaisesRegex(ValueError, 'never increase'):
            broker.approve(SimpleNamespace(id=value['id'], minutes=15))

    def test_reboot_closes_window(self):
        value = self.make_request(window=True)
        self.approve(value)
        with patch.object(broker, 'boot_id', return_value='other-boot'):
            with self.assertRaises(ValueError):
                broker.run_request(SimpleNamespace(id=value['id'], argv=['/usr/bin/id']))


if __name__ == '__main__':
    unittest.main(verbosity=2)
