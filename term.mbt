///|
/// Render a term as SMT-LIB text.
pub fn Term::to_string(self : Term) -> String {
  try! native_string(ffi_describe(self.native))
}

///|
pub impl Show for Term with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
pub extend Term with Show::{output}

///|
pub impl Eq for Term with fn equal(self, other) {
  ffi_equal(self.native, other.native)
}

///|
pub extend Term with Eq::{equal, not_equal}

///|
pub fn Term::kind(self : Term) -> Kind {
  ffi_term_kind(self.native)
}

///|
pub fn Term::sort(self : Term) -> Sort raise Cvc5Error {
  { native: checked(ffi_term_sort(self.native)), }
}

///|
/// The immediate children of the expression, in order.
pub fn Term::children(self : Term) -> Array[Term] raise Cvc5Error {
  native_terms(ffi_term_children(self.native))
}

///|
pub fn Term::symbol(self : Term) -> String? raise Cvc5Error {
  if ffi_term_has_symbol(self.native) {
    Some(native_string(ffi_term_symbol(self.native)))
  } else {
    None
  }
}

///|
/// Read a Boolean literal. The C API terminates the process for other values.
pub fn Term::get_boolean_value(self : Term) -> Bool raise Cvc5Error {
  ffi_boolean(checked(ffi_term_boolean_value(self.native)))
}

///|
/// Read an arbitrary-precision integral value as decimal digits.
pub fn Term::get_integer_value(self : Term) -> String raise Cvc5Error {
  native_string(ffi_term_integer_value(self.native))
}

///|
/// Read an integral value that fits in Int64. The C API terminates the process
/// on overflow or if the term is not an integral value.
pub fn Term::get_int64_value(self : Term) -> Int64 raise Cvc5Error {
  ffi_integer(checked(ffi_term_int64_value(self.native)))
}

///|
/// Read an exact rational value as a string, without rounding to floating point.
pub fn Term::get_real_value(self : Term) -> String raise Cvc5Error {
  native_string(ffi_term_real_value(self.native))
}

///|
/// Read the literal Unicode contents, without SMT-LIB quotes or escapes.
pub fn Term::get_string_value(self : Term) -> String raise Cvc5Error {
  ffi_unicode(checked(ffi_term_string_value(self.native)))
}

///|
/// Read an unsigned bit-vector value in base 2, 10, or 16.
pub fn Term::get_bit_vector_value(
  self : Term,
  base? : UInt = 2,
) -> String raise Cvc5Error {
  native_string(ffi_term_bit_vector_value(self.native, base))
}

///|
/// Simultaneously substitute terms. Both lists must have equal length.
pub fn Term::substitute(
  self : Term,
  from : ArrayView[Term],
  to : ArrayView[Term],
) -> Term raise Cvc5Error {
  if from.length() != to.length() {
    raise ApiError("Substitution lists must have equal length")
  }
  {
    native: checked(
      ffi_term_substitute(self.native, term_handles(from), term_handles(to)),
    ),
  }
}
