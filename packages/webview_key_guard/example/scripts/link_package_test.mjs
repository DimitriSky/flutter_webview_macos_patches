import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, realpath, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { linkPackage } from './link_package.mjs';

test('link points at one source, can be repeated, and does not copy changes', async t => {
  const root = await mkdtemp(join(tmpdir(), 'key-lab-link-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  const source = join(root, 'source package');
  const lab = join(root, 'lab');
  await mkdir(join(source, 'lib'), { recursive: true });
  await mkdir(join(source, 'macos/webview_key_guard'), { recursive: true });
  await writeFile(join(source, 'pubspec.yaml'), 'name: webview_key_guard\n');
  await writeFile(join(source, 'lib/webview_key_guard.dart'), 'original');
  await writeFile(join(source, 'macos/webview_key_guard/Package.swift'), 'fixture');
  const canonical = await realpath(source);
  assert.equal(await linkPackage(source, lab), canonical);
  assert.equal(await linkPackage(source, lab), canonical);
  const link = join(lab, '.local-packages/webview_key_guard');
  assert.equal(await realpath(link), canonical);
  await writeFile(join(source, 'lib/webview_key_guard.dart'), 'changed');
  assert.equal(await readFile(join(link, 'lib/webview_key_guard.dart'), 'utf8'), 'changed');

  const otherLab = join(root, 'other lab');
  const occupied = join(otherLab, '.local-packages/webview_key_guard');
  await mkdir(occupied, { recursive: true });
  await writeFile(join(occupied, 'keep.txt'), 'keep');
  await assert.rejects(linkPackage(source, otherLab), /Refusing to replace/);
  assert.equal(await readFile(join(occupied, 'keep.txt'), 'utf8'), 'keep');
  await assert.rejects(linkPackage(join(root, 'missing'), lab));
  assert.equal(await realpath(link), canonical);
});
