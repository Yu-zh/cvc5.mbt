# Yu-zh/cvc5.mbt

Native MoonBit bindings for [cvc5](https://cvc5.github.io/), pinned to **1.3.4**,
using its public C API and a C11 shim.
The API follows the `TermManager` / `Solver` organization of
[cvc5-rs](https://github.com/cvc5/cvc5-rs).

## Quick start

Install a current MoonBit toolchain, Node.js 18 or newer, a C11 compiler,
`curl`, and `unzip`. Then, in this repository:

```sh
moon test
moon run cmd/main
```

The first build downloads a pinned upstream shared-library archive and checks
its SHA-256 against the digest in `build.js`. Later builds reuse `.cvc5/` and
work offline. No global cvc5 installation is needed. The `cvc5` executable alone
is not sufficient: a binding also needs the headers and native libraries.

This first version follows the C API's error behavior: invalid upstream API
calls can terminate the process. `Cvc5Error` covers binding-level checks only;
see [Error handling](#error-handling) before using untrusted expressions or options.

Prebuilt archives are configured for macOS and Linux, on arm64 and x86-64.
Local validation was performed on macOS arm64. Windows, browser/Wasm backends,
cross-compilation, and static linking are not supported by this version.
Linux binaries require the glibc and C++ runtime supported by the upstream
archive; use a source build on systems where that archive is incompatible.

For a consuming project, add the module dependency:

```sh
moon add Yu-zh/cvc5.mbt
```

Then import it in `moon.pkg` with the alias `cvc5`:

```moonbit nocheck
///|
import {
  "Yu-zh/cvc5.mbt" @cvc5,
}
```

Build that project with `--target native` or set `preferred_target = "native"`
in its `moon.mod`. There are no consumer-side compiler or linker settings.
The local `tests/consumer` workspace demonstrates dependency usage:

```sh
moon -C tests/consumer run .
moon -C tests/consumer run . --release
```

## Example

```mbt check
///|
test "README: solve an integer equation" {
  let tm = @cvc5.TermManager::new()
  let solver = @cvc5.Solver::new(tm)
  solver.set_logic("QF_LIA")
  solver.set_option("produce-models", "true")
  let x = tm.mk_const(tm.integer_sort(), "x")
  let equation = tm.mk_term(Equal, [
    tm.mk_term(Add, [x, tm.mk_integer(1)]),
    tm.mk_integer(43),
  ])
  solver.assert_formula(equation)
  assert_true(solver.check_sat() is Sat)
  assert_eq(solver.get_value(x).get_int64_value(), 42)
}
```

## Building cvc5 from source

The same MoonBit prebuild hook can build cvc5 and its dependencies:

```sh
CVC5_BUILD=source moon test
```

This requires Git, CMake (3.31 or newer recommended), Make, a C/C++17 toolchain,
and Python (3.11 or newer recommended). The hook fetches the 1.3.4 tag, verifies
its pinned Git commit, configures a `Production` shared-library build with GPL
features disabled and LibPoly enabled, then runs CMake's build and install
steps. cvc5 downloads and verifies GMP, CaDiCaL, SymFPU, and LibPoly as needed.
The initial build can take several minutes. Build output goes to stderr.
cvc5 itself is still implemented in C++; the binding does not require a C++
compiler when using prebuilt libraries or `CVC5_PREFIX`.

The installation and intermediate build directory are cached separately from
MoonBit's `_build`, so `moon clean` does not rebuild cvc5. Failed compilations
retain their build directory and can resume. Changing compiler settings creates
a separate cache entry. Builds for the same cache entry are serialized.

To build a local cvc5 1.3.4 checkout:

```sh
CVC5_SOURCE_DIR=/absolute/path/to/cvc5 moon test
```

If you modify that checkout after a successful build, choose a fresh
`CVC5_CACHE_DIR` to rebuild it; the completed dependency cache is not a source
file watcher.

You can also use an existing **shared-library installation**:

```sh
CVC5_PREFIX=/absolute/path/to/cvc5/install moon test
```

It must contain `include/cvc5/c/cvc5.h` and `lib/libcvc5.dylib` (macOS),
`lib/libcvc5.so` (Linux), or the corresponding `lib64` directory. Use 1.3.4;
compile-time checks reject changes to the enum ABI. A custom installation's
dependency libraries must also be available to the dynamic loader.

| Variable | Purpose |
| --- | --- |
| `CVC5_BUILD` | `prebuilt` (default) or `source` |
| `CVC5_PREFIX` | Existing installation; takes priority over building/downloading |
| `CVC5_SOURCE_DIR` | Local 1.3.4 source checkout; implies source mode |
| `CVC5_CACHE_DIR` | Dependency cache; defaults to this module's `.cvc5/` |
| `CVC5_JOBS` | Source-build parallelism; defaults to at most 8 workers |
| `CVC5_CMAKE` | CMake executable for a source build |
| `CVC5_PYTHON` | Python interpreter passed to CMake |
| `CC` | C compiler for the binding shim and source builds; defaults to `cc` |
| `CXX` | C++ compiler for building cvc5 itself; not used to compile the shim |

Downloads respect the usual `HTTPS_PROXY` / `HTTP_PROXY` environment variables.
If an abruptly terminated build leaves a `.lock` directory, first verify no
build is using it, then remove that specific lock before retrying.

The executables use an rpath to the selected installation. To distribute an
executable to another machine, bundle the native libraries and configure the
loader paths for that bundle. The cached shared libraries are not embedded in
the executable. Bundling libraries also requires complying with their licenses;
see [License](#license) and [third-party notices](THIRD_PARTY_NOTICES.md).

## API and ownership

- `TermManager` constructs sorts, literals, constants, variables, terms, and
  indexed `Op` values. `mk_term` exposes all cvc5 1.3.4 term kinds; each kind
  retains its upstream arity and sort requirements.
- `Solver` supports options and logics, assertions, satisfiability checks,
  temporary assumptions, incremental scopes, simplification, models, and
  unsat cores, plus full proofs in Cooperating Proof Calculus (CPC) format.
- `Term` supports children, sorts, symbols, substitution, SMT-LIB display, and
  typed literal extraction. Arbitrary integers and exact rationals can be
  exchanged as strings. String literals preserve embedded NULs and Unicode
  scalar values up to U+2FFFF.
- `SatResult` distinguishes `Sat`, `Unsat`, and `Unknown(reason)`.

Terms, sorts, operators, and solvers retain their term manager automatically.
There is no manual `delete`, `close`, or `clone` requirement. Combining objects
from different managers raises `Cvc5Error::ApiError`. Handles are intended for
single-threaded use; reference counting does not make the solver thread-safe.

The C11 shim uses `cvc5_*_copy` / `cvc5_*_release` and MoonBit external-object
finalizers. Each native value is released before its retained term manager.
Solver results are copied into lifetime-independent snapshots, and temporary
C API strings and arrays are copied before their storage can be reused.
Every non-primitive FFI parameter has an explicit borrowing annotation.

### CPC proof retrieval

Enable `produce-proofs` before solving, then call `get_proof_cpc()` immediately
after an `Unsat` result from `check_sat()` or `check_sat_assuming()`. It returns
the full refutation as an owned `String`, which remains valid after further
solver calls or destruction of the solver. Retrieve it before changing assertions
or scopes: cvc5 1.3.4 can abort if retrieval follows `reset_assertions()`.
Calling it without proof production enabled or outside the unsatisfiable solver
state is also a fatal upstream API error.

```mbt check
///|
test "README: retrieve a CPC proof" {
  let tm = @cvc5.TermManager::new()
  let solver = @cvc5.Solver::new(tm)
  solver.set_logic("QF_UF")
  solver.set_option("produce-proofs", "true")
  solver.set_option("proof-format-mode", "cpc")
  solver.set_option("proof-granularity", "dsl-rewrite")
  let p = tm.mk_const(tm.boolean_sort(), "p")
  solver.assert_formula(p)
  solver.assert_formula(tm.mk_term(Not, [p]))
  assert_true(solver.check_sat() is Unsat)
  let proof = solver.get_proof_cpc()
  assert_true(proof.contains("false :rule contra"))
}
```

`get_proof_cpc()` explicitly selects CPC, regardless of `proof-format-mode`.
Other proof options still apply; the optional `proof-granularity=dsl-rewrite`
setting gives more detailed rewrite steps. Set these options before solving.
No `dump-proofs` option is needed for API retrieval.

CPC proofs can be checked with [Ethos](https://github.com/cvc5/ethos).
Unsupported proof rules can appear as `trust` steps, causing Ethos to report
`incomplete` rather than `correct`; more detail does not guarantee a proof without
trust steps. See the [cvc5 CPC documentation](https://cvc5.github.io/docs/cvc5-1.3.4/proofs/output_cpc.html).

### Error handling

cvc5 1.3.4's C API prints a diagnostic and exits on invalid operations, including
wrong term sorts or arities, invalid options, and invalid solver states. These
errors **cannot be caught with MoonBit `try ... catch`** in this version.
`Sat`, `Unsat`, and `Unknown(reason)` remain ordinary solver results, not errors.
See the [upstream error implementation](https://github.com/cvc5/cvc5/blob/cvc5-1.3.4/src/api/c/cvc5_checks.h).

Public signatures retain `raise Cvc5Error` for binding-level checks, such as
mixing managers, mismatched substitution arrays, or invalid string conversion.
This is not a general validation layer for cvc5 inputs. Recoverable upstream
API errors are deferred to a later version.

Symbol names, logic/option strings, and numeric text cannot contain embedded
NUL characters because the C API accepts them as NUL-terminated strings. The
binding rejects those inputs instead of truncating them. **String literals**
created with `mk_string` preserve NULs and Unicode scalar values within the
SMT-LIB alphabet, U+0000–U+2FFFF. Code points above U+2FFFF and unpaired UTF-16
surrogates raise `Cvc5Error` instead of silently changing the string. MoonBit
encodes and decodes SMT-LIB Unicode escapes, passing `Bytes` across the FFI
boundary to work around the C API's lack of length-bearing string access.

This is an initial binding, not full cvc5-rs API parity. Dedicated datatype,
floating-point, finite-field, and collection-value constructors, SMT-LIB
parsing, SyGuS, proof-node inspection, other proof formats, and statistics are
not wrapped yet. No binding to cvc5's parser library is required for the current
API.

## Build-system design and development

`moon.mod` registers `build.js` using MoonBit's experimental
`--moonbit-unstable-prebuild` hook. The script supplies include flags through
`${build.CVC5_STUB_FLAGS}` and propagates libraries/rpaths through `link_configs`.
`moon.pkg` compiles only `cvc5_stub.c`; CMake handles cvc5's own source tree.
The hook also runs when this module is used as a dependency.

This uses the module configuration approach from
[Kaida-Amethyst/llvm 0.5.0](https://mooncakes.io/docs/Kaida-Amethyst/llvm@0.5.0).
[mizchi/wasmtime 0.1.6](https://mooncakes.io/docs/mizchi/wasmtime@0.1.6)
provides a source-build example, but documents that its package pre-build hook
must be invoked explicitly by consumers. See MoonBit's
[prebuild protocol](https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html#experimental-pre-build-config-script).
That protocol is experimental and may require updates with future toolchains.

```sh
moon check --deny-warn
moon test
moon test --release
node scripts/test-c-api-errors.js
moon -C tests/consumer run . --release
moon info && moon fmt
```

The checked-in interfaces are generated by `moon info`. To update enum
declarations and their C ABI assertions together:

```sh
node scripts/generate-kinds.js /path/to/cvc5/include/cvc5/cvc5_kind.h
moon info && moon fmt
```

The generator preserves cvc5's copyright and BSD-3-Clause attribution in all
three generated files. When updating the pinned cvc5 version, also update its
notice, the upstream copies in `licenses/cvc5/`, and `THIRD_PARTY_NOTICES.md`.

`tests/fatal-api` contains deliberately invalid calls and is not part of the
ordinary test suite. `scripts/test-c-api-errors.js` builds that fixture and
executes each case in a separate child process, checking for cvc5's diagnostic
and exit status. Do not run its tests directly expecting a successful exit.

## License

The original binding code is licensed under [Apache-2.0](LICENSE). The generated
cvc5 API definitions retain [cvc5's BSD-3-Clause license](licenses/cvc5/COPYING)
and [author attribution](licenses/cvc5/AUTHORS). See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for the affected files and their
upstream source. Neither license implies endorsement by the upstream projects.

The Git source distribution and Mooncakes package do not include native cvc5
libraries. `build.js` downloads an upstream archive or builds the libraries
separately; dependency caches are excluded from Git and the package.

`ENABLE_GPL=OFF` disables optional GPL features, not LGPL dependencies. The
configured source build still uses [GMP](https://gmplib.org/manual/Copying) and
[LibPoly](https://github.com/SRI-CSL/libpoly/blob/v0.2.1/LICENCE), available under
LGPLv3 terms. A custom `CVC5_PREFIX` can have different dependencies or features.

If you redistribute native libraries or linked executables, review the exact
build's licenses, include the required notices and license texts, provide the
required corresponding library-source access, and preserve users' ability to
replace or relink the LGPL components. Dynamic linking does not remove these
obligations. The [redistribution checklist](THIRD_PARTY_NOTICES.md#redistributing-native-binaries)
is a starting point, not legal clearance for a binary release.
