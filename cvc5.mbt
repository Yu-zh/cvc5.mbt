///|
/// A binding-level validation error, such as mixing term managers or an
/// unsupported embedded NUL in a C string argument. This does not catch errors
/// raised inside cvc5: the cvc5 1.3.4 C API terminates the process on API misuse.
pub(all) suberror Cvc5Error {
  ApiError(String)
} derive(Debug, Eq)

///|
pub extend Cvc5Error with Debug::{to_repr}

///|
pub extend Cvc5Error with Eq::{equal, not_equal}

///|
/// Native C storage with a finalizer. Only checked handles reach the public API.
type Native

///|
/// Creates sorts, terms, and operators. Derived objects keep this manager alive.
pub struct TermManager {
  priv native : Native
}

///|
/// A solver sharing a term manager. Multiple solvers may share the same manager.
pub struct Solver {
  priv native : Native
}

///|
/// The type of a term. Sorts from different managers cannot be combined.
pub struct Sort {
  priv native : Native
}

///|
/// An immutable expression. Its manager remains alive as long as the term does.
pub struct Term {
  priv native : Native
}

///|
/// An operator, optionally indexed (for example, bit-vector extraction).
pub struct Op {
  priv native : Native
}

///|
/// A satisfiability result, independent of the lifetime of the solver.
pub(all) enum SatResult {
  Sat
  Unsat
  Unknown(String)
} derive(Debug, Eq)

///|
pub fn SatResult::is_sat(self : SatResult) -> Bool {
  self is Sat
}

///|
pub extend SatResult with Debug::{to_repr}

///|
pub extend SatResult with Eq::{equal, not_equal}

///|
pub fn SatResult::is_unsat(self : SatResult) -> Bool {
  self is Unsat
}

///|
pub fn SatResult::is_unknown(self : SatResult) -> Bool {
  self is Unknown(_)
}

///|
fn checked(native : Native) -> Native raise Cvc5Error {
  if ffi_has_error(native) {
    raise ApiError(@utf8.decode_lossy(ffi_error(native)))
  }
  native
}

///|
fn native_string(native : Native) -> String raise Cvc5Error {
  @utf8.decode_lossy(ffi_string(checked(native)))
}

///|
fn native_terms(native : Native) -> Array[Term] raise Cvc5Error {
  let native = checked(native)
  [
    for i in 0..<ffi_terms_length(native) => {
      { native: checked(ffi_terms_get(native, i)), }
    }
  ]
}

///|
fn term_handles(terms : ArrayView[Term]) -> FixedArray[Native] {
  FixedArray::makei(terms.length(), i => terms[i].native)
}

///|
fn sort_handles(sorts : ArrayView[Sort]) -> FixedArray[Native] {
  FixedArray::makei(sorts.length(), i => sorts[i].native)
}

///|
fn sat_result(native : Native) -> SatResult raise Cvc5Error {
  let native = checked(native)
  match ffi_result_status(native) {
    0 => Sat
    1 => Unsat
    _ => Unknown(@utf8.decode_lossy(ffi_unknown_reason(native)))
  }
}
