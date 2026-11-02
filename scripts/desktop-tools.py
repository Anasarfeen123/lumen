#!/usr/bin/env python3
"""Local helpers for Lumen Tools. Paths are argv/JSON data, never shell code.

File jobs emit JSON lines, run serially in the shell, refuse overwrites and
remove only their own incomplete output on cancellation. Storage is read-only.
"""
import argparse
import ctypes
import errno
import json
import os
from pathlib import Path
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time
import uuid
import zipfile


def emit(value):
    print(json.dumps(value, ensure_ascii=True), flush=True)


def path(value):
    return Path(os.path.abspath(os.path.expanduser(value)))


def user_dir(name):
    try:
        value = subprocess.check_output(['xdg-user-dir', name], text=True).strip()
        if value:
            return path(value)
    except (OSError, subprocess.CalledProcessError):
        pass
    return Path.home() / {'DOWNLOAD': 'Downloads', 'DOCUMENTS': 'Documents',
                          'PICTURES': 'Pictures', 'DESKTOP': 'Desktop'}[name]


def destination_path(value):
    if not value.startswith('xdg:'):
        return path(value)
    name = value[4:]
    if name == 'projects':
        return Path.home() / 'Projects'
    mapping = dict(documents='DOCUMENTS', downloads='DOWNLOAD', desktop='DESKTOP', pictures='PICTURES')
    if name not in mapping:
        raise ValueError('Unknown destination')
    return user_dir(mapping[name])


def entry(p):
    s = p.lstat()
    directory = p.is_dir()
    return dict(path=str(p), uri=p.as_uri(), name=p.name, directory=directory,
                link=p.is_symlink(), size=s.st_size if not directory else 0,
                modified=s.st_mtime * 1000)


def browse(value):
    folder = path(value).resolve(strict=True)
    rows, unreadable = [], 0
    with os.scandir(folder) as items:
        for item in items:
            try:
                rows.append(entry(Path(item.path)))
            except OSError:
                unreadable += 1
    rows.sort(key=lambda e: (not e['directory'], e['name'].casefold()))
    return dict(path=str(folder), parent=str(folder.parent), entries=rows[:2000],
                total=len(rows), unreadable=unreadable, truncated=len(rows) > 2000)


def screenshots():
    folder = user_dir('PICTURES') / 'Screenshots'
    rows = []
    if folder.is_dir():
        for p in folder.iterdir():
            try:
                if p.is_file() and p.suffix.lower() in ('.png', '.jpg', '.jpeg', '.webp'):
                    rows.append(entry(p))
            except OSError:
                continue
    rows.sort(key=lambda e: e['modified'], reverse=True)
    return dict(path=str(folder), entries=rows[:100])


def storage(value):
    """One filesystem, no symlink traversal; progress once per direct child."""
    folder = path(value).resolve(strict=True)
    device = folder.stat().st_dev
    rows, seen, skipped = [], set(), 0

    def size(p):
        nonlocal skipped
        try:
            s = p.lstat()
            if s.st_dev != device or stat.S_ISLNK(s.st_mode):
                skipped += 1
                return 0
            key = (s.st_dev, s.st_ino)
            if key in seen:
                return 0
            seen.add(key)
            total = s.st_blocks * 512
            if stat.S_ISDIR(s.st_mode):
                with os.scandir(p) as children:
                    for child in children:
                        total += size(Path(child.path))
            return total
        except (OSError, RecursionError):
            skipped += 1
            return 0

    with os.scandir(folder) as items:
        for item in items:
            p = Path(item.path)
            try:
                e = entry(p)
            except OSError:
                skipped += 1
                continue
            e['size'] = size(p)
            rows.append(e)
            emit(dict(type='scanning', name=p.name, count=len(rows)))
    rows.sort(key=lambda e: e['size'], reverse=True)
    disk = shutil.disk_usage(folder)
    emit(dict(type='storage', path=str(folder), parent=str(folder.parent), entries=rows,
              total=sum(e['size'] for e in rows), skipped=skipped,
              capacity=disk.total, used=disk.used, free=disk.free))


class Cancelled(Exception):
    pass


def cancel(_signum, _frame):
    raise Cancelled()


class FileJob:
    def __init__(self, request):
        self.kind = request['kind']
        if self.kind not in ('copy', 'move', 'compress'):
            raise ValueError('Unknown file operation')
        self.sources = [path(p) for p in request['paths']]
        if not self.sources or len(self.sources) > 500:
            raise ValueError('Choose between 1 and 500 items')
        self.destination = destination_path(request['destination']).resolve(strict=True)
        if not self.destination.is_dir():
            raise ValueError('Destination must be a folder')
        self.completed, self.created = [], []
        self.bytes, self.total, self.last = 0, 0, 0
        names = set()
        for src in self.sources:
            if not os.path.lexists(src):
                raise ValueError('Missing item: ' + str(src))
            if src.name in names:
                raise ValueError('Two items have the same name: ' + src.name)
            names.add(src.name)
            dst = self.destination / src.name
            if src.resolve() == dst.resolve() or (src.is_dir() and
                    (src.resolve() == self.destination or src.resolve() in self.destination.parents)):
                raise ValueError('Choose a destination outside the source folder')
            if self.kind != 'compress' and os.path.lexists(dst):
                raise FileExistsError('Already exists; nothing overwritten: ' + dst.name)

    def files(self, p):
        # Do not traverse symlinks or copy special devices/FIFOs.
        s = p.lstat()
        if stat.S_ISLNK(s.st_mode):
            return
        if stat.S_ISREG(s.st_mode):
            yield p
        elif stat.S_ISDIR(s.st_mode):
            with os.scandir(p) as children:
                for child in children:
                    yield from self.files(Path(child.path))
        else:
            raise ValueError('Unsupported file type: ' + str(p))

    def progress(self, name, force=False):
        if force or time.monotonic() - self.last > .12:
            self.last = time.monotonic()
            emit(dict(type='progress', bytes=self.bytes, total=self.total,
                      progress=min(.999, self.bytes / max(1, self.total)), name=name))

    def copy(self, src, dst):
        s = src.lstat()
        if stat.S_ISLNK(s.st_mode):
            os.symlink(os.readlink(src), dst)
            self.created.append(dst)
        elif stat.S_ISDIR(s.st_mode):
            dst.mkdir()
            self.created.append(dst)
            with os.scandir(src) as children:
                for child in children:
                    self.copy(Path(child.path), dst / child.name)
            shutil.copystat(src, dst, follow_symlinks=False)
        elif stat.S_ISREG(s.st_mode):
            # 'xb' is atomic no-overwrite, including dangling symlinks.
            with src.open('rb') as source, dst.open('xb') as target:
                self.created.append(dst)
                while chunk := source.read(1024 * 1024):
                    target.write(chunk)
                    self.bytes += len(chunk)
                    self.progress(src.name)
            shutil.copystat(src, dst, follow_symlinks=False)
        else:
            raise ValueError('Unsupported file type: ' + str(src))

    def move(self, src, dst):
        # Linux renameat2(RENAME_NOREPLACE): atomic and never clobbers a race.
        # Cross-filesystem moves deliberately require Copy, avoiding a partly
        # deleted source tree if a cancellable copy is interrupted.
        libc = ctypes.CDLL(None, use_errno=True)
        if not hasattr(libc, 'renameat2'):
            raise ValueError('Atomic move unavailable; use Copy instead')
        if libc.renameat2(-100, os.fsencode(src), -100, os.fsencode(dst), 1):
            err = ctypes.get_errno()
            if err == errno.EXDEV:
                raise ValueError('Different filesystem; use Copy instead. Source kept.')
            raise OSError(err, os.strerror(err), str(dst))

    def archive(self):
        name = self.sources[0].stem if len(self.sources) == 1 else 'Archive'
        out = self.destination / (name + '.zip')
        n = 2
        while os.path.lexists(out):
            out = self.destination / f'{name} ({n}).zip'
            n += 1
        # ZIP skips symlinks explicitly, never follows them to private files.
        with out.open('xb') as handle:
            self.created.append(out)
            with zipfile.ZipFile(handle, 'w', zipfile.ZIP_DEFLATED) as z:
                for src in self.sources:
                    if src.is_symlink():
                        raise ValueError('Archive symlinks separately; no links followed')
                    if src.is_dir():
                        z.writestr(src.name + '/', '')
                        # Include empty directories, and fail rather than silently
                        # omit a link or an unreadable part of a directory tree.
                        for base, dirs, files in os.walk(src, followlinks=False,
                                                        onerror=lambda e: (_ for _ in ()).throw(e)):
                            for name in dirs + files:
                                p = Path(base) / name
                                if p.is_symlink():
                                    raise ValueError('Archive contains a symlink: ' + str(p))
                                if p.is_dir():
                                    z.writestr(str(p.relative_to(src.parent)) + '/', '')
                    for p in self.files(src):
                        with p.open('rb') as source, z.open(str(p.relative_to(src.parent)), 'w', force_zip64=True) as target:
                            while chunk := source.read(1024 * 1024):
                                target.write(chunk)
                                self.bytes += len(chunk)
                                self.progress(p.name)
        self.completed.append(str(out))
        self.created = []

    def run(self):
        self.total = len(self.sources) if self.kind == "move" else sum(p.stat().st_size for src in self.sources for p in self.files(src))
        self.progress('Preparing', True)
        if self.kind == 'compress':
            self.archive()
        else:
            for src in self.sources:
                dst = self.destination / src.name
                if self.kind == 'copy':
                    self.copy(src, dst)
                else:
                    # SIGTERM is deferred over the atomic rename + bookkeeping.
                    previous = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGTERM})
                    try:
                        self.move(src, dst)
                        self.completed.append(str(dst))
                        self.bytes += 1
                        self.progress(src.name, True)
                    finally:
                        signal.pthread_sigmask(signal.SIG_SETMASK, previous)
                    continue
                self.completed.append(str(dst))
                self.created = []
        emit(dict(type='done', completed=self.completed, destination=str(self.destination), progress=1))

    def cleanup(self):
        for p in reversed(self.created):
            try:
                if p.is_dir() and not p.is_symlink():
                    p.rmdir()
                else:
                    p.unlink()
            except OSError:
                pass


def copy_clipboard(data=None, mime=None, source=None):
    args = ['wl-copy'] + (['--type', mime] if mime else [])
    with tempfile.TemporaryFile() as errors:
        result = subprocess.run(args, input=data, stdin=source, stdout=subprocess.DEVNULL,
                                stderr=errors, timeout=15)
        if result.returncode:
            errors.seek(0)
            raise ValueError(errors.read().decode(errors='replace').strip()[-700:] or 'Could not access the clipboard')


def action(kind, value):
    p = path(value)
    if not p.is_file():
        raise ValueError('File is no longer available')
    if kind == 'copy-image':
        mime = {'.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
                '.webp': 'image/webp'}.get(p.suffix.lower())
        if not mime:
            raise ValueError('Unsupported image format')
        with p.open('rb') as f:
            copy_clipboard(mime=mime, source=f)
        return dict(message='Image copied')
    if kind == 'ocr':
        result = subprocess.run(['tesseract', str(p), 'stdout'], capture_output=True, text=True, check=True)
        if not result.stdout.strip():
            raise ValueError('No text found in this image')
        copy_clipboard(data=result.stdout.encode())
        return dict(message='Text copied', text=result.stdout)
    if kind == 'edit':
        if not shutil.which('swappy'):
            raise ValueError('Install Swappy to annotate, crop and blur screenshots')
        out = p.with_name(p.stem + '-edited-' + uuid.uuid4().hex[:6] + '.png')
        # Swappy produces a PNG, and the original is always kept.
        subprocess.run(['swappy', '-f', str(p), '-o', str(out)], check=True)
        return dict(message='Edited copy saved' if out.exists() else 'Editor closed without saving', path=str(out) if out.exists() else '')
    raise ValueError('Unknown image action')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['folders', 'browse', 'screenshots', 'storage', 'job', 'action', 'pick-colour', 'copy-text'])
    parser.add_argument('args', nargs='*')
    args = parser.parse_args()
    job = None
    signal.signal(signal.SIGTERM, cancel)
    signal.signal(signal.SIGINT, cancel)
    try:
        if args.command == 'folders':
            emit([dict(name=name, path=str(p)) for name, p in [
                ('Home', Path.home()), ('Downloads', user_dir('DOWNLOAD')),
                ('Documents', user_dir('DOCUMENTS')), ('Pictures', user_dir('PICTURES')),
                ('Projects', Path.home() / 'Projects')] if p.is_dir()])
        elif args.command == 'browse':
            emit(browse(args.args[0]))
        elif args.command == 'screenshots':
            emit(screenshots())
        elif args.command == 'storage':
            storage(args.args[0])
        elif args.command == 'action':
            emit(action(*args.args))
        elif args.command == 'pick-colour':
            result = subprocess.run(['hyprpicker', '--no-fancy'], capture_output=True, text=True)
            import re
            match = re.fullmatch(r'#[0-9a-fA-F]{6}', result.stdout.strip())
            if result.returncode == 0 and match:
                emit(dict(colour=match.group().upper()))
            else:
                emit(dict(cancelled=True))
        elif args.command == 'copy-text':
            copy_clipboard(data=args.args[0].encode())
            emit(dict(message='Copied'))
        elif args.command == 'job':
            job = FileJob(json.loads(args.args[0]))
            job.run()
    except Cancelled:
        if job:
            job.cleanup()
        emit(dict(type='cancelled', completed=job.completed if job else []))
        return 130
    except (OSError, ValueError, KeyError, IndexError, subprocess.SubprocessError, RecursionError) as exc:
        if job:
            job.cleanup()
        emit(dict(type='error', error=str(exc), completed=job.completed if job else []))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
