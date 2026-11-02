#!/usr/bin/env python3
"""Circle to Search helpers. Each action returns one JSON result, after success.

Each capture owns a private session directory. Cleanup never removes another
capture's files, and clipboard errors remain visible in the selection sheet.
"""
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import uuid


def runtime_root():
    return Path(os.environ.get('XDG_RUNTIME_DIR', tempfile.gettempdir())) / 'lumen-lens'


def private_path(value):
    base = runtime_root()
    if base.is_symlink():
        raise ValueError('Unsafe capture directory')
    p = Path(value).absolute()
    if not p.resolve().is_relative_to(base.resolve()) or p.resolve() == base.resolve():
        raise ValueError('Capture path is outside the private capture directory')
    return p


def checked(args, timeout=40):
    try:
        return subprocess.run(args, capture_output=True, text=True, check=True, timeout=timeout).stdout.strip()
    except FileNotFoundError as exc:
        raise ValueError('Required tool is not installed: ' + str(args[0])) from exc
    except subprocess.CalledProcessError as exc:
        detail = (exc.stderr or '').strip()
        raise ValueError(detail[-700:] or str(args[0]) + ' could not finish') from exc


def clipboard(file=None, text=None):
    # A clipboard owner forks to keep serving data. Give it a real error file
    # rather than a pipe that its background child might keep open forever.
    with tempfile.TemporaryFile() as errors:
        if file is not None:
            with Path(file).open('rb') as source:
                result = subprocess.run(['wl-copy', '--type', 'image/png'], stdin=source,
                                        stdout=subprocess.DEVNULL, stderr=errors, timeout=15)
        else:
            result = subprocess.run(['wl-copy', '--type', 'text/plain;charset=utf-8'],
                                    input=text.encode(), stdout=subprocess.DEVNULL, stderr=errors, timeout=15)
        if result.returncode:
            errors.seek(0)
            raise ValueError(errors.read().decode(errors='replace').strip()[-700:] or 'Could not access the clipboard')


def image_size(file):
    value = checked(['magick', 'identify', '-format', '%w %h', str(file)])
    w, h = value.split()
    return int(w), int(h)


def shot(monitor, output):
    out = private_path(output)
    base = runtime_root()
    base.mkdir(mode=0o700, parents=True, exist_ok=True)
    if base.stat().st_uid != os.getuid():
        raise ValueError('Capture directory belongs to another user')
    base.chmod(0o700)
    out.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    checked(['grim', '-o', monitor, str(out)])
    out.chmod(0o600)
    w, h = image_size(out)
    return dict(path=str(out), width=w, height=h)


def crop(source, x, y, width, height, output):
    src, out = private_path(source), private_path(output)
    w, h = image_size(src)
    values = [float(v) for v in (x, y, width, height)]
    if not all(math.isfinite(v) for v in values):
        raise ValueError('Invalid selection')
    x, y, width, height = values
    x0, y0 = max(0, math.floor(x)), max(0, math.floor(y))
    x1, y1 = min(w, math.ceil(x + width)), min(h, math.ceil(y + height))
    if x1 <= x0 or y1 <= y0:
        raise ValueError('Select an area inside the screen')
    checked(['magick', str(src), '-crop', f'{x1-x0}x{y1-y0}+{x0}+{y0}', '+repage', 'PNG:' + str(out)])
    out.chmod(0o600)
    return dict(path=str(out), width=x1-x0, height=y1-y0)


def ocr(source):
    src = private_path(source)
    if not shutil.which('tesseract'):
        raise ValueError('Install Tesseract to copy or search text. Image actions are still available.')
    with tempfile.TemporaryDirectory(prefix='ocr-', dir=src.parent) as tmp:
        enlarged = Path(tmp) / 'image.png'
        checked(['magick', str(src), '-resize', '200%', str(enlarged)])
        result = checked(['tesseract', str(enlarged), 'stdout', '-l', 'eng', '--psm', '3'])
        if not result:
            result = checked(['tesseract', str(enlarged), 'stdout', '-l', 'eng', '--psm', '6'])
        return dict(text=result)


def keep(source, output):
    src = private_path(source)
    out = Path(output)
    out.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    with src.open('rb') as reader, out.open('xb') as writer:
        os.fchmod(writer.fileno(), 0o600)
        shutil.copyfileobj(reader, writer)
    return dict(path=str(out))


def save(source):
    try:
        folder = checked(['xdg-user-dir', 'PICTURES'])
    except ValueError:
        folder = str(Path.home() / 'Pictures')
    folder = Path(folder or str(Path.home() / 'Pictures')) / 'Screenshots'
    from datetime import datetime
    return keep(source, str(folder / ('Lens_' + datetime.now().strftime('%Y-%m-%d_%H-%M-%S_') + uuid.uuid4().hex[:6] + '.png')))


def clean(session):
    directory = private_path(session)
    # Only a session directory, never the shared base or an arbitrary file.
    if directory.parent.resolve() != runtime_root().resolve() or not directory.name.startswith('session-') or directory.is_symlink():
        raise ValueError('Invalid capture session')
    if directory.exists():
        shutil.rmtree(directory)
    return dict(cleaned=True)


def main(argv):
    command, *args = argv
    if command == 'shot':
        return shot(*args)
    if command == 'crop':
        return crop(*args)
    if command == 'ocr':
        return ocr(*args)
    if command == 'keep':
        return keep(*args)
    if command == 'save':
        return save(*args)
    if command == 'clean':
        return clean(*args)
    if command == 'copy-image':
        source = private_path(args[0])
        image_size(source)  # a missing/incomplete image is an error, not success
        clipboard(file=source)
        return dict(message='Copied the picture')
    if command == 'copy-text':
        clipboard(text=args[0])
        return dict(message='Copied the text')
    raise ValueError('Unknown Circle to Search action')


if __name__ == '__main__':
    try:
        print(json.dumps(main(sys.argv[1:])), flush=True)
    except (OSError, ValueError, TypeError, subprocess.SubprocessError) as exc:
        print(json.dumps(dict(error=str(exc))), flush=True)
        sys.exit(1)
