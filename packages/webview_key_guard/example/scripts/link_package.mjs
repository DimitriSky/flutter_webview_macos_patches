import { access, lstat, mkdir, realpath, symlink, unlink } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const labRoot = fileURLToPath(new URL('..', import.meta.url));

export async function linkPackage(packageRoot, projectRoot = labRoot) {
  const source = await realpath(packageRoot);
  for (const file of ['pubspec.yaml', 'lib/webview_key_guard.dart',
    'macos/webview_key_guard/Package.swift']) {
    await access(join(source, file));
  }
  const link = join(projectRoot, '.local-packages/webview_key_guard');
  await mkdir(dirname(link), { recursive: true });
  const existing = await lstat(link).catch(error => {
    if (error.code !== 'ENOENT') throw error;
    return null;
  });
  if (existing) {
    if (!existing.isSymbolicLink()) throw new Error(`Refusing to replace a real file: ${link}`);
    if (await realpath(link).catch(() => null) === source) return source;
    await unlink(link);
  }
  await symlink(source, link, 'dir');
  return source;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    if (process.argv.length !== 3) throw new Error('Usage: node scripts/link_package.mjs /path/to/webview_key_guard');
    console.log(`webview_key_guard -> ${await linkPackage(process.argv[2])}`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
