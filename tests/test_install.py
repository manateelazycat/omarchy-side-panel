import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("installer", Path(__file__).parents[1] / "install.py")
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class InstallationLifecycle(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.config_home = self.root / "config"
        self.state_home = self.root / "state"
        self.config_path = self.config_home / "omarchy/shell.json"
        self.plugin = self.config_home / "omarchy/plugins" / installer.PLUGIN_ID
        self.plugin.mkdir(parents=True)
        (self.plugin / "old.txt").write_text("previous plugin")
        self.original_config = {"version": 1, "idle": {"lock": 421}, "bar": {
            "id": installer.PLUGIN_ID, "position": "bottom",
            "layout": {"right": [{"id": "custom.widget", "option": 7}]}},
            "plugins": [{"id": "custom.service"}], "disabledPlugins": ["omarchy.menu"]}
        installer.atomic_json(self.config_path, self.original_config)
        self.service = self.plugin.parent / installer.STYLED_SERVICES[0] / "Service.qml"
        self.service.parent.mkdir()
        self.service.write_text("import QtQuick\nRectangle {\n    id: card\n}\n")
        self.original_service = self.service.read_bytes()
        self.state_dir = self.state_home / "omarchy-side-panel"
        self.state_dir.mkdir(parents=True)
        installer.atomic_json(self.state_dir / "installation.json", {"previousBarId": "omarchy.bar"})
        self.running = True
        self.locked = False
        self.kill_fails = False
        self.events = []
        self.environment = patch.dict(os.environ, {
            "XDG_CONFIG_HOME": str(self.config_home), "XDG_STATE_HOME": str(self.state_home),
            "XDG_CACHE_HOME": str(self.root / "cache")})
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.processes = patch.object(installer.subprocess, "run", side_effect=self.run_command)
        self.processes.start()
        self.addCleanup(self.processes.stop)
        original_replace = os.replace

        def checked_replace(source, destination):
            destination = Path(destination)
            source = Path(source)
            if self.plugin.parent in destination.parents or self.plugin.parent in source.parents or destination == self.config_path:
                self.assertFalse(self.running, "Live shell observed a plugin/config mutation")
                self.events.append("mutation")
            return original_replace(source, destination)

        replacement = patch.object(installer.os, "replace", side_effect=checked_replace)
        replacement.start()
        self.addCleanup(replacement.stop)

    def run_command(self, command, **kwargs):
        code, output = 0, ""
        if command == ["omarchy-hyprland-session-locked"]:
            code = 0 if self.locked else 1
        elif command == ["systemctl", "--user", "show-environment"]:
            output = "OMARCHY_PATH=/usr/share/omarchy\n"
        elif command[:2] == ["quickshell", "kill"]:
            self.assertEqual(command[2:], ["-p", "/usr/share/omarchy/shell", "--any-display"])
            if self.running and not self.kill_fails:
                self.running = False
                self.events.append("stop")
            else:
                code = 1
        elif command[:3] == ["omarchy-shell", "shell", "ping"]:
            code, output = (0, "ok") if self.running else (1, "")
        elif command == ["omarchy", "toggle", "idle", "status"]:
            output = '{"enabled":true}'
        elif command == ["omarchy", "restart", "shell"]:
            self.assertFalse(self.running)
            self.running = True
            self.events.append("start")
        elif command == ["omarchy-shell", "idle", "disable"]:
            self.assertTrue(self.running)
        else:
            self.fail("Unexpected command (including any live plugin reload): " + repr(command))
        if kwargs.get("check") and code:
            raise subprocess.CalledProcessError(code, command)
        return subprocess.CompletedProcess(command, code, output, "")

    def invoke(self, action="install", activation_error=None):
        with patch("sys.argv", ["install.py", action]), patch.object(
                installer, "verify_activation", side_effect=activation_error, return_value=4):
            installer.main()

    def test_install_changes_files_only_after_exit_and_preserves_settings(self):
        self.invoke()
        self.assertEqual(self.events.count("stop"), 1)
        self.assertEqual(self.events.count("start"), 1)
        self.assertEqual(self.events[0], "stop")
        self.assertEqual(self.events[-1], "start")
        self.assertEqual(json.loads(self.config_path.read_text()), self.original_config)
        self.assertTrue((self.plugin / "Bar.qml").exists())
        self.assertTrue((self.plugin / "TrayRecovery.qml").exists())
        self.assertTrue((self.plugin / "recover-tray.py").exists())
        self.assertTrue((self.plugin / "TrayController.qml").exists())
        self.assertTrue((self.plugin / "TrayModel.js").exists())
        self.assertTrue((self.plugin / "licenses/OMARCHY-LICENSE").exists())
        self.assertIn(b"SidePanelUi.PopupStyler", self.service.read_bytes())

    def with_legacy_tray(self):
        self.original_config["bar"]["layout"].update({
            "left": ["io.github.manateelazycat.tray-bar"],
            "center": [{"id": "omarchy.clock", "format": "HH:mm"}],
            "right": [{"id": "io.github.manateelazycat.tray-bar",
                       "hidden": ["chat"], "pinned": ["steam"], "custom": 17}]})
        self.config_path.write_text(json.dumps(self.original_config))

    def test_migrates_legacy_tray_and_retains_settings_and_unrelated_layout(self):
        self.with_legacy_tray()
        self.invoke()
        config = json.loads(self.config_path.read_text())
        self.assertEqual(config["bar"]["layout"]["left"], ["omarchy.tray"])
        self.assertEqual(config["bar"]["layout"]["right"], [
            {"id": "omarchy.tray", "hidden": ["chat"], "pinned": ["steam"], "custom": 17}])
        self.assertEqual(config["bar"]["layout"]["center"], self.original_config["bar"]["layout"]["center"])
        self.assertEqual(config["plugins"], self.original_config["plugins"])
        self.assertEqual(config["disabledPlugins"], self.original_config["disabledPlugins"])
        self.assertEqual(config["idle"], self.original_config["idle"])

    def test_failed_activation_restores_legacy_tray_configuration(self):
        self.with_legacy_tray()
        with self.assertRaises(SystemExit):
            self.invoke(activation_error=RuntimeError("tray failed"))
        self.assertEqual(json.loads(self.config_path.read_text()), self.original_config)
        self.assertEqual((self.plugin / "old.txt").read_text(), "previous plugin")

    def test_failed_activation_rolls_back_plugin_configuration_and_services(self):
        with self.assertRaises(SystemExit):
            self.invoke(activation_error=RuntimeError("not ready"))
        self.assertEqual((self.plugin / "old.txt").read_text(), "previous plugin")
        self.assertFalse((self.plugin / "Bar.qml").exists())
        self.assertEqual(json.loads(self.config_path.read_text()), self.original_config)
        self.assertEqual(self.service.read_bytes(), self.original_service)
        self.assertTrue(self.running)
        self.assertEqual(self.events.count("stop"), 2)

    def test_locked_session_keeps_running_shell_and_all_live_files(self):
        self.locked = True
        with self.assertRaises(SystemExit):
            self.invoke()
        self.assertEqual(self.events, [])
        self.assertTrue(self.running)
        self.assertTrue((self.plugin / "old.txt").exists())
        self.assertEqual(json.loads(self.config_path.read_text()), self.original_config)
        self.assertEqual(self.service.read_bytes(), self.original_service)

    def test_failed_stop_does_not_replace_plugin(self):
        self.kill_fails = True
        with self.assertRaises(SystemExit):
            self.invoke()
        self.assertTrue(self.running)
        self.assertEqual(self.events, [])
        self.assertTrue((self.plugin / "old.txt").exists())

    def test_restore_and_uninstall_also_update_offline(self):
        self.invoke("restore")
        config = json.loads(self.config_path.read_text())
        self.assertEqual(config["bar"]["id"], "omarchy.bar")
        self.assertEqual(config["bar"]["layout"], self.original_config["bar"]["layout"])
        self.assertTrue(self.plugin.exists())
        self.invoke("uninstall")
        self.assertFalse(self.plugin.exists())
        self.assertTrue(self.running)
        self.assertFalse((self.state_dir / "installation.json").exists())


if __name__ == "__main__":
    unittest.main()
