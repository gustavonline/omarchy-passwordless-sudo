import importlib.machinery
import importlib.util
from pathlib import Path
import unittest
import tempfile
from unittest.mock import patch

loader = importlib.machinery.SourceFileLoader('control', str(Path(__file__).with_name('agent-access')))
spec = importlib.util.spec_from_loader(loader.name, loader)
control = importlib.util.module_from_spec(spec)
loader.exec_module(control)


class ControlTests(unittest.TestCase):
    def test_skill_registration_is_idempotent(self):
        with tempfile.TemporaryDirectory() as home:
            control.install_skill(home)
            control.install_skill(home)
            self.assertTrue(all(p.resolve() == control.HERE for p in control.skill_links(home)))
            self.assertEqual((Path(home) / '.local/bin/omarchy-agent-access').resolve(), control.HERE / 'agent-access')

    def test_existing_skill_is_preserved(self):
        with tempfile.TemporaryDirectory() as home:
            first = control.skill_links(home)[0]
            first.mkdir(parents=True)
            (first / 'SKILL.md').write_text('Owner method')
            with self.assertRaises(ValueError):
                control.install_skill(home)
            self.assertEqual((first / 'SKILL.md').read_text(), 'Owner method')

    def test_active_window_status(self):
        value = control.window_status({'version': '2.0.0', 'enrolled': True, 'request': {
            'mode': 'window', 'state': 'approved', 'live': True, 'seconds_left': 42, 'id': 'x'}})
        self.assertTrue(value['active'])
        self.assertEqual(value['remainingSeconds'], 42)

    def test_expired_pending_and_old_versions_never_report_active(self):
        for version, mode, state, live in [('2.0.0', 'window', 'approved', False),
                                          ('2.0.0', 'window', 'pending', True),
                                          ('2.0.0', 'command', 'approved', True),
                                          ('1.0', 'window', 'approved', True)]:
            self.assertFalse(control.window_status({'version': version, 'request': {
                'mode': mode, 'state': state, 'live': live}})['active'])

    def test_duration_limits(self):
        for value in ['0', '16', '9999', '-1', 'abc', '５']:
            with self.assertRaises(ValueError):
                control.minutes(value)
        self.assertEqual(control.minutes('5'), '5')

    def test_agent_request_passes_duration_and_reason_without_otp(self):
        with patch.object(control.sys, 'argv', ['control', 'request', '7', 'Repair packages']), \
             patch.object(control, 'broker', return_value='{}') as broker, patch('builtins.print'):
            control.main()
            broker.assert_called_once_with('request', '--minutes', '7', '--reason', 'Repair packages')

    def test_approve_uses_hidden_terminal_prompt(self):
        with patch.object(control.sys, 'argv', ['control', 'approve']), \
             patch.object(control, 'broker_status', return_value={'request': {'id': 'abc', 'live': True, 'state': 'pending'}}), \
             patch.object(control, 'terminal') as terminal:
            control.main()
            terminal.assert_called_once_with(['/usr/bin/sudo', '-n', control.BROKER, 'approve', 'abc'])

    def test_approve_requires_pending_request(self):
        with patch.object(control.sys, 'argv', ['control', 'approve']), \
             patch.object(control, 'broker_status', return_value={'request': None}):
            with self.assertRaises(ValueError):
                control.main()

    def test_quick_creates_default_window_then_opens_code_prompt(self):
        with patch.object(control.sys, 'argv', ['control', 'quick', '7']), \
             patch.object(control, 'broker_status', return_value={'enrolled': True, 'request': None}), \
             patch.object(control, 'broker', return_value='{"id":"new"}') as broker, \
             patch.object(control, 'terminal') as terminal:
            control.main()
            broker.assert_called_once_with('request', '--minutes', '7', '--reason', 'Local maintenance')
            terminal.assert_called_once_with(['/usr/bin/sudo', '-n', control.BROKER, 'approve', 'new'])

    def test_quick_reuses_pending_request_and_never_extends_open_window(self):
        with patch.object(control.sys, 'argv', ['control', 'quick', '5']), \
             patch.object(control, 'broker_status', return_value={'enrolled': True, 'request': {'id': 'old', 'state': 'pending', 'live': True}}), \
             patch.object(control, 'broker') as broker, patch.object(control, 'terminal') as terminal:
            control.main()
            broker.assert_not_called()
            self.assertEqual(terminal.call_args.args[0][-1], 'old')
        with patch.object(control.sys, 'argv', ['control', 'quick', '5']), \
             patch.object(control, 'broker_status', return_value={'enrolled': True, 'request': {'state': 'approved', 'live': True}}):
            with self.assertRaises(ValueError):
                control.main()


if __name__ == '__main__':
    unittest.main(verbosity=2)
