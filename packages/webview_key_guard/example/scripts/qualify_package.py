#!/usr/bin/env python3
"""Run the owned native fixture; save counts without machine paths or input text.

From example/, select its existing SDK with KEY_GUARD_FLUTTER_BIN if needed.
Raw runner output stays in an OS temporary log, outside committed evidence.
"""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

runner = os.environ.get('KEY_GUARD_FLUTTER_BIN', 'flutter')
environment = dict(os.environ, KEY_LAB_WEBKIT_OBSERVATION='off', KEY_LAB_TRACE_STACKS='off')
root = Path(__file__).resolve().parents[1]
command = [runner, 'test', '--no-pub', 'integration_test/package_isolation_test.dart', '-d', 'macos']
with tempfile.NamedTemporaryFile(prefix='key-guard-review-', suffix='.log', mode='w+', delete=False) as log:
    print('Running isolated native package qualification', flush=True)
    try:
        result = subprocess.run(command, cwd=root, env=environment, stdout=log,
                                stderr=subprocess.STDOUT, timeout=240)
    except subprocess.TimeoutExpired:
        raise SystemExit(f'Qualification timed out; inspect temporary log: {log.name}')
    log.seek(0)
    output = log.read()
    matches = re.findall(r'KEY_GUARD_REVIEW_RESULT=(\{[^\r\n]*\})', output)
    if result.returncode != 0 or not matches:
        raise SystemExit(f'Qualification failed; inspect temporary log: {log.name}')

evidence = json.loads(matches[-1])
assert evidence['passed'] and not evidence['physicalKeyboardQualified']
assert evidence['duplicates'] == evidence['prevented'] == evidence['labSuppressed'] == evidence['labRouted'] == 0
assert not evidence['restartRequired']
# Include versions only, never the SDK's machine-specific path.
version = json.loads(subprocess.check_output([runner, '--version', '--machine'], text=True))
evidence['flutterVersion'] = version['frameworkVersion']
evidence['dartVersion'] = version['dartSdkVersion']
target = root / 'evidence/package-isolation-review-20261008.json'
target.write_text(json.dumps(evidence, indent=2) + '\n')
print(json.dumps(evidence), flush=True)
