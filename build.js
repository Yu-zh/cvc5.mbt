'use strict';

// Moon's prebuild protocol reserves stdout for JSON. All subprocess output and
// progress belong on stderr. No generated paths are written into moon.pkg.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');

const VERSION = '1.3.4';
const CACHE_SCHEMA = 2;
const REVISION = 'f3b21c4483d3b88dc63cb7cd3e5eb092eee5e341';
const ARTIFACTS = {
  'darwin-arm64': ['macOS-arm64', 'cba119b4e9b82c6101f022e57825d2ad1357fa4f386a0d43ec5e61a1906f51fe'],
  'darwin-x64': ['macOS-x86_64', 'ae2c82c0ca23d697210bb572c908c369e2d06fff490b1d58d2e703dc5a1818ed'],
  'linux-arm64': ['Linux-arm64', 'fb9ff008525f349ae539d7a6328b1f1088a4f7b4863119a7332055bd2629a8dc'],
  'linux-x64': ['Linux-x86_64', 'd33bd6622c2672af4c718b0e6759193ecd44f7ebfab42f437b767829cc63bc79'],
};

function report(message) {
  console.error(`[cvc5.mbt] ${message}`);
}

function run(command, args, env, cwd, capture = false) {
  const result = spawnSync(command, args, {
    env, cwd, encoding: 'utf8',
    stdio: ['ignore', capture ? 'pipe' : 2, 2],
  });
  if (result.error) throw new Error(`${command}: ${result.error.message}`);
  if (result.status !== 0) throw new Error(`${command} failed (exit ${result.status})`);
  return result.stdout?.trim();
}

// These strings are parsed as compiler arguments by Moon (not by a shell).
function quote(value) {
  if (/[\0\r\n]/.test(value)) throw new Error('Invalid newline or NUL in build path');
  return "'" + value.replace(/'/g, "'\\''") + "'";
}

function installation(prefix, platform = process.platform) {
  const header = path.join(prefix, 'include', 'cvc5', 'c', 'cvc5.h');
  const name = platform === 'darwin' ? 'libcvc5.dylib' : 'libcvc5.so';
  const libdir = ['lib', 'lib64'].map(p => path.join(prefix, p))
    .find(p => fs.existsSync(path.join(p, name)));
  if (!fs.existsSync(header) || !libdir) {
    throw new Error(`Expected include/cvc5/c/cvc5.h and lib[64]/${name} in ${prefix}. ` +
      'CVC5_PREFIX must point to a shared-library installation, not the cvc5 executable.');
  }
  return { prefix, libdir, library: path.join(libdir, name) };
}

function configuration(install, env) {
  return {
    vars: {
      CVC5_CC: env.CC || 'cc',
      CVC5_STUB_FLAGS: `-std=c11 -fPIC -I${quote(path.join(install.prefix, 'include'))}`,
    },
    link_configs: [{
      package: 'moonbitlang/cvc5',
      // Module prebuild link_configs propagate to consumers. Package-local
      // cc-link-flags alone are insufficient for a reusable native dependency.
      // The shared cvc5 library carries its own C++ runtime dependency. The
      // binding itself uses only C symbols and needs no C++ compiler/runtime flags.
      link_flags: `${quote(install.library)} -pthread -Wl,-rpath,${quote(install.libdir)}`,
    }],
  };
}

function downloadPrebuilt(staging, artifact, env) {
  const [platform, digest] = artifact;
  const name = `cvc5-${platform}-shared`;
  const archive = path.join(staging, 'cvc5.zip');
  const url = `https://github.com/cvc5/cvc5/releases/download/cvc5-${VERSION}/${name}.zip`;
  report(`Downloading cvc5 ${VERSION} (${platform})`);
  run('curl', ['--fail', '--location', '--silent', '--show-error', '--retry', '3',
    '--connect-timeout', '30', '--max-time', '600', '--output', archive, url], env);
  const actual = crypto.createHash('sha256').update(fs.readFileSync(archive)).digest('hex');
  if (actual !== digest) throw new Error(`SHA-256 mismatch for ${name}.zip`);
  run('unzip', ['-q', archive, '-d', staging], env);
  return path.join(staging, name);
}

function buildSource(staging, env, prefix) {
  let source = env.CVC5_SOURCE_DIR && path.resolve(env.CVC5_SOURCE_DIR);
  if (!source) {
    source = path.join(staging, 'source');
    if (!fs.existsSync(source)) {
      run('git', ['clone', '--depth', '1', '--branch', `cvc5-${VERSION}`,
        'https://github.com/cvc5/cvc5.git', source], env);
    }
    const revision = run('git', ['rev-parse', 'HEAD'], env, source, true);
    if (revision !== REVISION) throw new Error(`Unexpected cvc5 source revision: ${revision}`);
  }
  const versionFile = path.join(source, 'cmake', 'version-base.cmake');
  if (!fs.existsSync(versionFile) ||
      !fs.readFileSync(versionFile, 'utf8').includes(`set(CVC5_LAST_RELEASE "${VERSION}")`)) {
    throw new Error(`CVC5_SOURCE_DIR must contain cvc5 ${VERSION} sources`);
  }
  const build = path.join(staging, 'build');
  const cmake = env.CVC5_CMAKE || 'cmake';
  report(`Building cvc5 ${VERSION} from source; the first build can take several minutes`);
  run(cmake, ['-S', source, '-B', build, '-G', 'Unix Makefiles',
    '-DCMAKE_BUILD_TYPE=Production', '-DBUILD_SHARED_LIBS=ON',
    '-DENABLE_AUTO_DOWNLOAD=ON', '-DENABLE_GPL=OFF',
    '-DENABLE_UNIT_TESTING=OFF', '-DBUILD_BINDINGS_PYTHON=OFF',
    '-DBUILD_BINDINGS_JAVA=OFF', '-DBUILD_GMP=ON', '-DUSE_POLY=ON', '-DCMAKE_INSTALL_LIBDIR=lib',
    ...(env.CVC5_PYTHON ? [`-DPython_EXECUTABLE=${env.CVC5_PYTHON}`] : []),
    `-DCMAKE_INSTALL_PREFIX=${prefix}`], env);
  const jobs = env.CVC5_JOBS || String(Math.min(os.availableParallelism?.() || os.cpus().length, 8));
  if (!/^[1-9]\d*$/.test(jobs)) throw new Error('CVC5_JOBS must be a positive integer');
  run(cmake, ['--build', build, '--parallel', jobs], env);
  run(cmake, ['--install', build], env);
  return prefix;
}

async function prepare(env) {
  if (!['darwin', 'linux'].includes(process.platform)) {
    throw new Error('This binding currently supports native macOS and Linux builds.');
  }
  if (env.CVC5_PREFIX) return installation(path.resolve(env.CVC5_PREFIX));
  const mode = env.CVC5_BUILD || (env.CVC5_SOURCE_DIR ? 'source' : 'prebuilt');
  if (!['source', 'prebuilt'].includes(mode)) throw new Error('CVC5_BUILD must be prebuilt or source');
  const platform = `${process.platform}-${process.arch}`;
  const artifact = ARTIFACTS[platform];
  if (mode === 'prebuilt' && !artifact) {
    throw new Error(`No cvc5 binary for ${platform}; set CVC5_BUILD=source or CVC5_PREFIX.`);
  }
  // Local caches avoid modifying the toolchain and survive `moon clean`.
  const cache = path.resolve(env.CVC5_CACHE_DIR || path.join(__dirname, '.cvc5'));
  const identity = mode === 'prebuilt' ? artifact[1] : crypto.createHash('sha256')
    .update(JSON.stringify([CACHE_SCHEMA, REVISION, env.CVC5_SOURCE_DIR && path.resolve(env.CVC5_SOURCE_DIR),
      env.CC, env.CXX, env.CFLAGS, env.CXXFLAGS, env.CVC5_CMAKE, env.CVC5_PYTHON])).digest('hex');
  const root = path.join(cache, `${VERSION}-${platform}-${mode}-${identity.slice(0, 16)}`);
  const prefix = path.join(root, 'install');
  const marker = path.join(root, 'complete.json');
  function cached() {
    if (!fs.existsSync(marker)) return null;
    const metadata = JSON.parse(fs.readFileSync(marker, 'utf8'));
    if (metadata.identity !== identity) throw new Error(`Invalid cvc5 cache metadata: ${root}`);
    return installation(prefix);
  }
  const existing = cached();
  if (existing) return existing;
  fs.mkdirSync(cache, { recursive: true });
  const lock = root + '.lock';
  const deadline = Date.now() + 30 * 60 * 1000;
  for (;;) {
    try { fs.mkdirSync(lock); break; } catch (error) {
      if (error.code !== 'EEXIST') throw error;
      if (Date.now() >= deadline) throw new Error(`Timed out waiting for ${lock}; check for an interrupted build.`);
      await new Promise(resolve => setTimeout(resolve, 1000));
      const completed = cached();
      if (completed) return completed;
    }
  }
  // Source builds stay at a stable path so interrupted builds resume, and
  // CMake installs directly into the final prefix (including its rpaths).
  const staging = mode === 'source' ? root + '.work' : fs.mkdtempSync(path.join(cache, '.install-'));
  try {
    fs.mkdirSync(staging, { recursive: true });
    const completed = cached();
    if (completed) return completed;
    if (mode === 'prebuilt' && fs.existsSync(root)) throw new Error(`Incomplete cvc5 installation at ${root}; move it aside and retry.`);
    const installed = mode === 'prebuilt' ? downloadPrebuilt(staging, artifact, env) : buildSource(staging, env, prefix);
    installation(installed);
    // Publish only a complete installation. Failed builds leave no success stamp.
    if (mode === 'prebuilt') {
      fs.mkdirSync(root);
      fs.renameSync(installed, prefix);
    }
    fs.writeFileSync(marker, JSON.stringify({ version: VERSION, identity }));
    return installation(prefix);
  } finally {
    if (mode === 'prebuilt') fs.rmSync(staging, { recursive: true, force: true });
    fs.rmdirSync(lock);
  }
}

async function main() {
  const source = fs.readFileSync(0, 'utf8').trim();
  const input = source ? JSON.parse(source) : {};
  const env = { ...process.env, ...input.env };
  const install = await prepare(env);
  process.stdout.write(JSON.stringify(configuration(install, env)) + '\n');
}

module.exports = { configuration, installation, quote, ARTIFACTS, VERSION };
if (require.main === module) main().catch(error => {
  report(error.message);
  process.exitCode = 1;
});
