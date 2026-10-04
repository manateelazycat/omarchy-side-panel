import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("recovery", Path(__file__).parents[1] / "recover-tray.py")
recovery = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recovery)


class TrayRecovery(unittest.TestCase):
    def setUp(self):
        self.name = "org.kde.StatusNotifierItem-123-1"
        self.alias = "org.freedesktop.StatusNotifierItem-123-1"
        self.owner = ":1.20"
        self.names = {recovery.WATCHER: ":1.30", self.name: self.owner,
                      self.alias: self.owner, "org.example.Unrelated": ":1.40"}
        self.registered = []
        self.calls = []
        self.not_ready = False
        self.register_fails = False
        self.next_owner = self.owner
        mock = patch.object(recovery, "busctl", side_effect=self.busctl)
        mock.start()
        self.addCleanup(mock.stop)

    def busctl(self, *arguments):
        if arguments == ("--acquired", "list"):
            return [{"name": key, "connection": value} for key, value in self.names.items()] + [
                {"name": "org.freedesktop.DBus", "connection": None}]
        if arguments[0] == "get-property" and arguments[-1] == "RegisteredStatusNotifierItems":
            return {"type": "as", "data": self.registered[:]}
        if arguments[0] == "get-property" and arguments[-1] == "Id":
            if self.not_ready:
                raise subprocess.CalledProcessError(1, ["busctl"])
            return {"type": "s", "data": "wechat"}
        if arguments[-3:] == ("GetNameOwner", "s", self.alias):
            return {"type": "s", "data": [self.next_owner]}
        if arguments[-3:-1] == ("RegisterStatusNotifierItem", "s"):
            if self.register_fails:
                raise subprocess.CalledProcessError(1, ["busctl"])
            self.calls.append(arguments)
            self.registered.append(arguments[-1] + recovery.ITEM_PATH)
            return None
        self.fail("Unexpected D-Bus call: " + repr(arguments))

    def test_recovers_once_for_two_aliases_and_skips_unrelated_services(self):
        result = recovery.recover()
        self.assertEqual(result["recovered"], [self.alias])
        self.assertEqual(len(self.calls), 1)
        self.assertEqual(self.calls[0][1], ":1.30")
        self.assertEqual(recovery.recover()["recovered"], [])
        self.assertEqual(len(self.calls), 1)

    def test_existing_unique_owner_registration_is_not_duplicated(self):
        self.registered = [self.owner + recovery.ITEM_PATH]
        self.assertEqual(recovery.recover()["recovered"], [])
        self.assertEqual(self.calls, [])

    def test_existing_other_alias_registration_is_not_duplicated(self):
        self.registered = [self.name + recovery.ITEM_PATH]
        self.assertEqual(recovery.recover()["recovered"], [])
        self.assertEqual(self.calls, [])

    def test_delayed_object_export_is_retried(self):
        self.not_ready = True
        self.assertEqual(recovery.recover()["pending"], 1)
        self.assertEqual(self.calls, [])
        self.not_ready = False
        self.assertEqual(recovery.recover()["recovered"], [self.alias])

    def test_registration_failure_is_retried(self):
        self.register_fails = True
        self.assertEqual(recovery.recover()["pending"], 1)
        self.register_fails = False
        self.assertEqual(recovery.recover()["recovered"], [self.alias])

    def test_watcher_restart_recovers_the_existing_item_again(self):
        recovery.recover()
        del self.names[recovery.WATCHER]
        self.assertFalse(recovery.recover()["watcher"])
        self.names[recovery.WATCHER] = ":1.50"
        self.registered = []
        self.assertEqual(recovery.recover()["recovered"], [self.alias])
        self.assertEqual(self.calls[-1][1], ":1.50")

    def test_owner_change_during_validation_defers_registration(self):
        self.next_owner = ":1.99"
        self.assertEqual(recovery.recover()["pending"], 1)
        self.assertEqual(self.calls, [])


if __name__ == "__main__":
    unittest.main()
