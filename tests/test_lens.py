"""Circle to Search never reports success before an action finishes."""
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('lens', Path(__file__).resolve().parents[1] / 'scripts/lens.py')
lens = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(lens)


class LensTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        env = patch.dict(os.environ, XDG_RUNTIME_DIR=str(self.base))
        env.start()
        self.addCleanup(env.stop)
        self.session = lens.runtime_root() / 'session-one'
        self.session.mkdir(parents=True)

    def test_cleanup_only_removes_requested_session(self):
        other = lens.runtime_root() / 'session-two'
        other.mkdir()
        (self.session / 'piece.png').write_bytes(b'old')
        (other / 'screen.png').write_bytes(b'new')
        lens.clean(str(self.session))
        self.assertFalse(self.session.exists())
        self.assertEqual((other / 'screen.png').read_bytes(), b'new')
        with self.assertRaises(ValueError):
            lens.clean(str(lens.runtime_root()))

    def test_capture_path_cannot_escape_runtime_folder(self):
        for value in [self.base / 'other.png', self.session / '../../../elsewhere']:
            with self.assertRaises(ValueError):
                lens.private_path(str(value))
        link = self.session / 'escape'
        link.symlink_to(self.base, target_is_directory=True)
        with self.assertRaises(ValueError):
            lens.private_path(str(link / 'image.png'))

    def test_clipboard_error_is_not_success(self):
        source = self.session / 'piece.png'
        source.write_bytes(b'image')

        def fail(args, **kwargs):
            kwargs['stderr'].write(b'Wayland clipboard is unavailable')
            return subprocess.CompletedProcess(args, 1)

        with patch.object(lens, 'image_size', return_value=(40, 20)), patch.object(lens.subprocess, 'run', side_effect=fail):
            with self.assertRaisesRegex(ValueError, 'clipboard is unavailable'):
                lens.main(['copy-image', str(source)])

    def test_durable_copy_is_complete_before_return(self):
        source = self.session / 'piece.png'
        source.write_bytes(b'original image')
        target = self.base / 'saved/Lens.png'
        result = lens.keep(str(source), str(target))
        lens.clean(str(self.session))
        self.assertEqual(Path(result['path']).read_bytes(), b'original image')
        self.assertEqual(target.stat().st_mode & 0o777, 0o600)
        with self.assertRaises(FileExistsError):
            # Create a new source, but never overwrite an existing saved file.
            self.session.mkdir()
            source.write_bytes(b'new image')
            lens.keep(str(source), str(target))

    @unittest.skipUnless(shutil.which('magick'), 'ImageMagick is needed for image integration')
    def test_crop_clamps_to_screen_and_rejects_empty_selection(self):
        source = self.session / 'screen.png'
        subprocess.run(['magick', '-size', '120x80', 'xc:red', str(source)], check=True)
        target = self.session / 'piece.png'
        result = lens.crop(str(source), '-5', '10', '45', '30', str(target))
        self.assertEqual((result['width'], result['height']), (40, 30))
        self.assertEqual(lens.image_size(target), (40, 30))
        with self.assertRaises(ValueError):
            lens.crop(str(source), '150', '10', '20', '30', str(target))
        with self.assertRaises(ValueError):
            lens.crop(str(source), 'nan', '10', '20', '30', str(target))


if __name__ == '__main__':
    unittest.main()
