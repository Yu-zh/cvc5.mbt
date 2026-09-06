'use strict';

// Fatal upstream API errors cannot run in the regular MoonBit test process.
// Build the isolated fixture, derive its test selectors from Moon's metadata,
// and require a cvc5 diagnostic plus exit(1), not a crash or a MoonBit exception.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const target = fs.mkdtempSync(path.join(os.tmpdir(), 'cvc5-c-api-errors-'));
try {
  const build = spawnSync('moon', ['-C', 'tests/fatal-api', 'test', 'fatal_test.mbt', '--target', 'native',
    '--release', '--deny-warn', '--build-only', '--target-dir', target], {
    cwd: root, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024,
  });
  if (build.error) throw build.error;
  process.stderr.write(build.stderr);
  assert.equal(build.status, 0, `Fixture build failed:\n${build.stdout}`);
  const artifacts = build.stdout.trim().split('\n').map(line => {
    try { return JSON.parse(line); } catch { return null; }
  }).find(value => Array.isArray(value?.artifacts_path));
  assert.ok(artifacts, `Missing build artifacts:\n${build.stdout}`);
  let count = 0;
  for (const executable of artifacts.artifacts_path) {
    const match = /\.(blackbox|whitebox)_test\.exe$/.exec(executable);
    if (!match) continue;
    const metadata = JSON.parse(fs.readFileSync(path.join(path.dirname(executable),
      `__${match[1]}_test_info.json`), 'utf8'));
    for (const [file, tests] of Object.entries(metadata.tests)) {
      // Workspace builds may also list artifacts from other members.
      if (file !== 'fatal_test.mbt') continue;
      for (const test of tests) {
        const selector = `${file}:${test.index}-${test.index + 1}`;
        const result = spawnSync(executable, [selector], {
          encoding: 'utf8', timeout: 30_000, maxBuffer: 4 * 1024 * 1024,
        });
        if (result.error) throw result.error;
        const output = result.stdout + result.stderr;
        assert.equal(result.signal, null, `${test.name} crashed:\n${output}`);
        assert.equal(result.status, 1, `${test.name} did not exit(1):\n${output}`);
        assert.match(result.stderr, /cvc5: error:/, `${test.name}: missing cvc5 diagnostic:\n${output}`);
        console.log(`PASS: ${test.name} (cvc5 diagnostic, exit 1)`);
        ++count;
      }
    }
  }
  assert.ok(count > 0, 'No fatal-error cases were selected');
  console.log(`Fatal C API checks: ${count} passed`);
} finally {
  // Only remove the fresh temporary build directory created by this invocation.
  fs.rmSync(target, { recursive: true, force: true });
}
