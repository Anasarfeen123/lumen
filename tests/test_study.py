import importlib.util
import os
import pathlib
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


def load():
    spec = importlib.util.spec_from_file_location("study", ROOT / "scripts" / "study.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class StudyTests(unittest.TestCase):
    def setUp(self):
        self.S = load()
        self.dbms = {"code": "BACSE202", "title": "Database Systems", "folder": "/x/BACSE202 - Database Systems (DBMS)"}
        self.moc = {"code": "BACSE201", "title": "Models of Computation", "folder": "/x/BACSE201 - Models of Computation (MOC)"}

    def test_exam_type(self):
        S = self.S
        self.assertEqual(S.exam_type("CAT1"), "CAT 1")
        self.assertEqual(S.exam_type("CAT - II"), "CAT 2")
        self.assertEqual(S.exam_type("fat"), "FAT")

    def test_paper_fields(self):
        ex, yr, slot = self.S.paper_fields("Past Papers/CAT 1/BCSE302L - Database Systems - CAT-1 - Slot B2 - 2025 - Question Paper.pdf")
        self.assertEqual((ex, yr, slot), ("CAT 1", "2025", "B2"))
        self.assertEqual(self.S.paper_fields("dbms/FAT/2024 paper.pdf")[0], "FAT")

    def test_matching_by_title_and_alias(self):
        S = self.S
        self.assertTrue(S.paper_matches(self.moc, {"courseCode": "BCSE304L", "courseTitle": "Theory of Computation"}))
        self.assertTrue(S.paper_matches(self.dbms, {"courseCode": "BCSE302L", "courseTitle": "Database Systems"}))
        self.assertFalse(S.paper_matches(self.dbms, {"courseCode": "BCSE303L", "courseTitle": "Operating Systems"}))

    def test_folder_matching(self):
        S = self.S
        self.assertTrue(S.folder_matches(self.dbms, "all papers/DBMS ( Database management systems)/CAT1/a.pdf"))
        self.assertTrue(S.folder_matches(self.moc, "toc/TOC FAT.pdf"))
        self.assertFalse(S.folder_matches(self.dbms, "[PMCA503L] Database Systems/24FALL/a.pdf"))   # MCA: another syllabus
        self.assertFalse(S.folder_matches(self.moc, "micro/x.pdf"))

    def test_cards(self):
        cards = self.S.parse_cards("## CYK Algorithm\n- **Input:** a string w\n- **Candidate Key:** a minimal superkey\n", "c.md")
        qs = [c["q"] for c in cards]
        self.assertIn("CYK Algorithm — Input?", qs)
        self.assertIn("What is Candidate Key?", qs)

    def test_review_schedule(self):
        with tempfile.TemporaryDirectory() as d:
            self.S.STATE = d
            self.S.out = lambda o: None
            self.S.cmd_review("X", "card", 2)
            p1 = self.S.progress()["cards"]["card"]
            self.assertEqual(p1["interval"], 1)
            self.S.cmd_review("X", "card", 0)
            self.assertEqual(self.S.progress()["cards"]["card"]["reps"], 0)

    def test_safe_names(self):
        self.assertEqual(self.S.safe_name("CAT 1 2025 Slot B2"), "CAT 1 2025 Slot B2")
        self.assertNotIn("/", self.S.safe_name("../../etc/passwd"))


if __name__ == "__main__":
    unittest.main()
