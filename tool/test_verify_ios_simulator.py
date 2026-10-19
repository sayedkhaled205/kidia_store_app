import subprocess
import unittest

from verify_ios_simulator import verify


class SimulatorLaunchTest(unittest.TestCase):
    device = "12345678-1234-1234-1234-123456789012"
    bundle = "com.customer.store"

    def runner(self, command, **kwargs):
        if command[0] == "xcrun":
            return subprocess.CompletedProcess(command, 0, self.bundle + ": 12345\n", "")
        return subprocess.CompletedProcess(command, 0, "/CoreSimulator/Devices/" + self.device + "/data/Runner.app/Runner\n", "")

    def test_running_process_verified_for_bounded_interval(self):
        waits = []
        result = verify(self.device, self.bundle, self.runner, waits.append)
        self.assertEqual(waits, [3, 3, 3, 3])
        self.assertEqual(result["status"], "launched_and_alive")

    def test_immediate_exit_is_failure(self):
        def runner(command, **kwargs):
            return self.runner(command) if command[0] == "xcrun" else subprocess.CompletedProcess(command, 1, "", "")
        with self.assertRaisesRegex(ValueError, "exited"):
            verify(self.device, self.bundle, runner, lambda _: None)

    def test_later_crash_is_failure(self):
        checks = []
        def runner(command, **kwargs):
            if command[0] == "ps":
                checks.append(command)
                if len(checks) == 3:
                    return subprocess.CompletedProcess(command, 1, "", "")
            return self.runner(command)
        with self.assertRaisesRegex(ValueError, "exited"):
            verify(self.device, self.bundle, runner, lambda _: None)
        self.assertEqual(len(checks), 3)

    def test_other_simulator_process_is_failure(self):
        def runner(command, **kwargs):
            return self.runner(command) if command[0] == "xcrun" else subprocess.CompletedProcess(command, 0, "/other/Runner.app/Runner", "")
        with self.assertRaisesRegex(ValueError, "failed"):
            verify(self.device, self.bundle, runner, lambda _: None)

    def test_simctl_error_is_failure(self):
        def runner(command, **kwargs):
            return subprocess.CompletedProcess(command, 1, "", "Cannot launch")
        with self.assertRaisesRegex(ValueError, "could not launch"):
            verify(self.device, self.bundle, runner, lambda _: None)


if __name__ == "__main__":
    unittest.main()
