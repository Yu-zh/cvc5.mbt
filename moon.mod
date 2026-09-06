// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "moonbitlang/cvc5"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/Yu-zh/cvc5.mbt"

license = "Apache-2.0"

keywords = [ "smt", "solver", "cvc5", "ffi", "native" ]

preferred_target = "native"

description = "Native MoonBit bindings for the cvc5 SMT solver"

options(
  "--moonbit-unstable-prebuild": "build.js",
)
