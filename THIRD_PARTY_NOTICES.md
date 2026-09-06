# Third-party notices

Except for the material identified below, the original MoonBit binding code
and build helpers are licensed under [Apache-2.0](LICENSE). Third-party material
retains its own license and attribution; the module's Apache-2.0 declaration
does not replace those terms.

## Generated definitions from cvc5

The following files are derived from
[`include/cvc5/cvc5_kind.h`](https://github.com/cvc5/cvc5/blob/f3b21c4483d3b88dc63cb7cd3e5eb092eee5e341/include/cvc5/cvc5_kind.h)
in cvc5 1.3.4, commit `f3b21c4483d3b88dc63cb7cd3e5eb092eee5e341`:

- [kind.mbt](kind.mbt)
- [sort_kind.mbt](sort_kind.mbt)
- [kind_checks.inc](kind_checks.inc)

These generated files are distributed under BSD-3-Clause. Their upstream
copyright is held by the cvc5 authors and their institutional affiliations.
The upstream [COPYING](licenses/cvc5/COPYING) and [AUTHORS](licenses/cvc5/AUTHORS)
files are included verbatim from that commit.

The generator converts upstream enum names to MoonBit names, shifts MoonBit
tags by two to accommodate negative upstream values, omits the `LAST_*`
sentinels, and emits C assertions against the original values. It adds the
MoonBit declarations and trait implementations; it does not copy the solver
implementation. Attribution headers are emitted by the generator and must be
retained when regenerating or redistributing these files.

The copied `COPYING` describes the complete upstream cvc5 distribution. Its
references to other third-party files refer to that upstream distribution;
their presence in the text does not mean the corresponding libraries are
bundled with this source package.

## Separately obtained native dependencies

The Git source distribution and Mooncakes package do not contain native cvc5
libraries or the `.cvc5/` and `.repos/` dependency caches. The prebuild script
downloads a pinned upstream shared-library archive, builds cvc5 from source,
or uses the installation selected by `CVC5_PREFIX`.

Those native libraries have their own licenses. In particular,
`ENABLE_GPL=OFF` does not disable LGPL dependencies: the configured source build
uses [GMP](https://gmplib.org/manual/Copying) under its LGPLv3-or-later option and
[LibPoly](https://github.com/SRI-CSL/libpoly/blob/v0.2.1/src/poly.c) under
LGPLv3-or-later. Custom installations may enable additional dependencies,
including optional GPL libraries. Inspect the exact build you distribute.

## Redistributing native binaries

Before distributing native libraries or linked executables:

- Identify every included or linked component and its applicable license,
  including dependencies and compiler runtimes. The notices here cover this
  source package, not an arbitrary native-library bundle.
- Include all required copyright notices, license texts, and disclaimers.
  Preserve upstream notices, but check completeness rather than assuming the
  downloaded archive supplies everything required for your distribution.
- For LGPL components, give the required notice of their use and include the
  GPLv3 and LGPLv3 texts. Permit modification of the LGPL portions and reverse
  engineering to debug those modifications. Use a suitable replaceable shared
  library mechanism or provide the materials needed for relinking, and provide
  installation information where required. See
  [LGPLv3 section 4](https://www.gnu.org/licenses/lgpl-3.0.html#section4).
- When conveying LGPL library binaries, provide compliant access to their
  corresponding source, including applicable modifications and build scripts.
  A generic project-homepage link is not a substitute for identifying and
  maintaining access to the matching source. See
  [GPLv3 section 6](https://www.gnu.org/licenses/gpl-3.0.html#section6), incorporated
  by LGPLv3.

Dynamic linking does not eliminate notice or source-availability obligations.
This checklist is not a complete legal assessment of a future binary release;
its requirements depend on the components and distribution method selected.
