import importlib.util
import os
import pathlib
import tempfile
import time
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
try:
    import cryptography  # noqa: F401
    HAVE = True
except ImportError:
    HAVE = False


def load(state):
    os.environ["XDG_STATE_HOME"] = state
    spec = importlib.util.spec_from_file_location("findmy", ROOT / "scripts" / "findmy.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@unittest.skipUnless(HAVE, "needs python3-cryptography")
class FindMyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.F = load(self.tmp.name)
        self.F.out = lambda o: self.told.append(o)
        self.told, self.sent = [], []
        self.F.publish = lambda c, obj, attachment=None: self.sent.append(obj)
        self.F.locate = lambda: {"location": None}
        self.c = {"topic": "t", "key": self.F.b64u(os.urandom(32))}

    def tearDown(self):
        self.tmp.cleanup()

    def cmd(self, **kw):
        return dict({"frm": "phone", "id": str(time.time()), "t": int(time.time())}, **kw)

    def test_seal_round_trip_and_wrong_key(self):
        k = os.urandom(32)
        s = self.F.seal(k, {"a": 1})
        self.assertEqual(self.F.unseal(k, s), {"a": 1})
        self.assertIsNone(self.F.unseal(os.urandom(32), s))
        self.assertIsNone(self.F.unseal(k, "hello"))

    def test_ring_reaches_lumen(self):
        self.F.handle(self.c, self.cmd(cmd="ring"), [])
        self.assertEqual(self.told[0]["do"], "ring")

    def test_stale_ring_is_skipped(self):
        self.F.handle(self.c, self.cmd(cmd="ring", t=int(time.time()) - 3600), [])
        self.assertEqual(self.told, [])
        self.assertFalse(self.sent[0]["ok"])

    def test_replay_and_own_messages_ignored(self):
        seen = []
        c = self.cmd(cmd="stop")
        self.F.handle(self.c, c, seen)
        self.F.handle(self.c, c, seen)                     # the same id again
        self.F.handle(self.c, dict(c, id="x", frm="laptop"), seen)
        self.assertEqual(len(self.told), 1)

    def test_lock_turns_on_lost_mode(self):
        self.F.handle(self.c, self.cmd(cmd="lock", args={"message": "m", "phone": "1"}), [])
        self.assertTrue(self.F.read_json(self.F.LOST)["on"])
        self.assertIn({"do": "lock"}, self.told)


if __name__ == "__main__":
    unittest.main()
