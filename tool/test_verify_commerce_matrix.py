"""The test gate must reject skipped, interrupted and empty platform runs."""
import json
import unittest

from verify_commerce_matrix import SENTINEL, cases, command, summarize


def transcript(*, skipped=False, success=True, done=True):
    events = [
        {"type": "testStart", "test": {"id": 7, "name": SENTINEL}},
        {"type": "testDone", "testID": 7, "hidden": False, "skipped": skipped,
         "result": "success" if success else "error"},
    ]
    if done:
        events.append({"type": "done", "success": success})
    return "\n".join(map(json.dumps, events))


class CommerceMatrixTests(unittest.TestCase):
    def test_all_platforms_compile_two_distinct_merchants(self):
        for platform in ("woocommerce", "shopify", "odoo"):
            fixtures = list(cases(platform))
            self.assertEqual(len(fixtures), 2)
            self.assertNotEqual(fixtures[0]["origin"], fixtures[1]["origin"])
            for fixture in fixtures:
                args = command("flutter", fixture)
                self.assertIn(f"--dart-define=STORE_PLATFORM={platform}", args)
                self.assertIn(f'--dart-define=STORE_URL={fixture["origin"]}', args)
                self.assertIn(f"--dart-define=EXPECTED_MATRIX_PLATFORM={platform}", args)
                self.assertNotIn("--dart-define-from-file", " ".join(args))

    def test_completed_success_requires_the_binding_test(self):
        self.assertTrue(summarize(transcript(), 0)["passed"])
        for output, code in (("", 0), (transcript(skipped=True), 0),
                             (transcript(success=False), 0),
                             (transcript(done=False), 0), (transcript(), 1),
                             (transcript().replace(SENTINEL, "unrelated test"), 0)):
            with self.subTest(code=code, output=output):
                self.assertFalse(summarize(output, code)["passed"])

    def test_any_other_skipped_or_failed_test_rejects_the_case(self):
        for changes in ({"skipped": True}, {"result": "failure"}):
            event = {"type": "testDone", "testID": 8, "hidden": False,
                     "skipped": False, "result": "success"} | changes
            output = transcript() + "\n" + json.dumps(event)
            self.assertFalse(summarize(output, 0)["passed"])


if __name__ == "__main__":
    unittest.main()
