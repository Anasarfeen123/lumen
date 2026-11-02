"""Safety regressions for file jobs and the read-only storage explorer.
Run: python3 -m unittest discover -s tests
"""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

SPEC = importlib.util.spec_from_file_location('desktop_tools', Path(__file__).resolve().parents[1] / 'scripts/desktop-tools.py')
tools = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(tools)


class DesktopToolsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.src = self.base / 'source'
        self.dst = self.base / 'destination'
        self.src.mkdir()
        self.dst.mkdir()

    def job(self, kind, paths, destination=None):
        return tools.FileJob(dict(kind=kind, paths=[str(p) for p in paths], destination=str(destination or self.dst)))

    def run_job(self, job):
        with contextlib.redirect_stdout(io.StringIO()):
            job.run()

    def test_copy_preserves_tree_names_and_symlinks(self):
        folder = self.src / 'Notes #1 ? café'
        folder.mkdir()
        (folder / 'empty').mkdir()
        (folder / 'text.txt').write_text('hello')
        (folder / 'link').symlink_to('text.txt')
        self.run_job(self.job('copy', [folder]))
        copied = self.dst / folder.name
        self.assertEqual((copied / 'text.txt').read_text(), 'hello')
        self.assertTrue((copied / 'empty').is_dir())
        self.assertTrue((copied / 'link').is_symlink())
        self.assertEqual(os.readlink(copied / 'link'), 'text.txt')
        self.assertTrue(folder.exists())

    def test_existing_destination_is_never_overwritten(self):
        source = self.src / 'report.txt'
        source.write_text('new')
        (self.dst / source.name).write_text('original')
        for kind in ('copy', 'move'):
            with self.assertRaises(FileExistsError):
                self.job(kind, [source])
        self.assertEqual((self.dst / source.name).read_text(), 'original')
        self.assertEqual(source.read_text(), 'new')

    def test_copy_refuses_destination_created_after_preflight(self):
        source = self.src / 'report.txt'
        source.write_text('new')
        job = self.job('copy', [source])
        (self.dst / source.name).write_text('racing writer')
        with self.assertRaises(FileExistsError):
            self.run_job(job)
        job.cleanup()
        self.assertEqual((self.dst / source.name).read_text(), 'racing writer')

    def test_move_is_atomic_and_handles_a_racing_destination(self):
        source = self.src / 'report.txt'
        source.write_text('new')
        job = self.job('move', [source])
        (self.dst / source.name).write_text('keep')
        with self.assertRaises(OSError):
            self.run_job(job)
        self.assertEqual(source.read_text(), 'new')
        self.assertEqual((self.dst / source.name).read_text(), 'keep')

    def test_move_keeps_contents(self):
        source = self.src / 'report.txt'
        source.write_text('move me')
        self.run_job(self.job('move', [source]))
        self.assertFalse(source.exists())
        self.assertEqual((self.dst / source.name).read_text(), 'move me')

    def test_copy_and_zip_refuse_descendant_destination(self):
        nested = self.src / 'inside'
        nested.mkdir()
        for kind in ('copy', 'move', 'compress'):
            with self.assertRaises(ValueError):
                self.job(kind, [self.src], nested)

    def test_duplicate_names_fail_before_any_copy(self):
        other = self.base / 'other'
        other.mkdir()
        for parent in (self.src, other):
            (parent / 'same.txt').write_text('x')
        with self.assertRaises(ValueError):
            self.job('copy', [self.src / 'same.txt', other / 'same.txt'])
        self.assertEqual(list(self.dst.iterdir()), [])

    def test_cancel_removes_partial_item_and_keeps_completed_items(self):
        first, second = self.src / 'first', self.src / 'second'
        first.write_bytes(b'complete')
        second.write_bytes(b'x' * (2 * 1024 * 1024))
        job = self.job('copy', [first, second])
        real_progress = job.progress

        def progress(name, force=False):
            if name == second.name:
                raise tools.Cancelled()
            real_progress(name, force)

        with patch.object(job, 'progress', progress):
            with self.assertRaises(tools.Cancelled):
                self.run_job(job)
        job.cleanup()
        self.assertEqual((self.dst / first.name).read_bytes(), b'complete')
        self.assertFalse((self.dst / second.name).exists())
        self.assertTrue(first.exists() and second.exists())
        self.assertEqual(job.completed, [str(self.dst / first.name)])

    def test_zip_preserves_empty_folders_and_uses_unique_name(self):
        folder = self.src / 'project'
        folder.mkdir()
        (folder / 'empty').mkdir()
        (folder / 'file.txt').write_text('contents')
        (self.dst / 'project.zip').write_text('keep')
        job = self.job('compress', [folder])
        self.run_job(job)
        self.assertEqual((self.dst / 'project.zip').read_text(), 'keep')
        with zipfile.ZipFile(job.completed[0]) as z:
            self.assertIn('project/empty/', z.namelist())
            self.assertEqual(z.read('project/file.txt'), b'contents')

    def test_zip_symlink_failure_leaves_no_partial_archive(self):
        (self.src / 'link').symlink_to('/etc/passwd')
        job = self.job('compress', [self.src])
        with self.assertRaises(ValueError):
            self.run_job(job)
        job.cleanup()
        self.assertEqual(list(self.dst.iterdir()), [])

    def test_storage_skips_links_and_counts_hardlinks_once(self):
        file = self.src / 'one'
        file.write_bytes(b'x' * 8192)
        os.link(file, self.src / 'two')
        (self.src / 'link').symlink_to(self.base)
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            tools.storage(str(self.src))
        result = json.loads(output.getvalue().splitlines()[-1])
        self.assertEqual(result['total'], file.stat().st_blocks * 512)
        self.assertEqual(result['skipped'], 1)
        self.assertTrue(file.exists())

    def test_portal_encodes_special_characters_as_file_uri(self):
        file = self.src / 'report #1 ? café.txt'
        file.write_text('x')
        listing = tools.browse(str(self.src))
        self.assertEqual(listing['entries'][0]['uri'], file.as_uri())
        self.assertEqual(listing['entries'][0]['path'], str(file))

    def test_editor_saves_a_separate_png(self):
        original = self.src / 'capture.jpg'
        original.write_bytes(b'original')

        def editor(args, **kwargs):
            Path(args[-1]).write_bytes(b'edited PNG')

        with patch.object(tools.shutil, 'which', return_value='/usr/bin/swappy'), patch.object(tools.subprocess, 'run', side_effect=editor):
            result = tools.action('edit', str(original))
        self.assertNotEqual(result['path'], str(original))
        self.assertEqual(Path(result['path']).suffix, '.png')
        self.assertEqual(original.read_bytes(), b'original')


if __name__ == '__main__':
    unittest.main()
