///|
/// Create a term manager; derived objects retain it automatically.
pub fn TermManager::new() -> TermManager raise Cvc5Error {
  { native: checked(ffi_tm_new()), }
}

///|
/// The boolean sort.
pub fn TermManager::boolean_sort(self : TermManager) -> Sort raise Cvc5Error {
  { native: checked(ffi_boolean_sort(self.native)), }
}

///|
/// The integer sort.
pub fn TermManager::integer_sort(self : TermManager) -> Sort raise Cvc5Error {
  { native: checked(ffi_integer_sort(self.native)), }
}

///|
/// The real sort.
pub fn TermManager::real_sort(self : TermManager) -> Sort raise Cvc5Error {
  { native: checked(ffi_real_sort(self.native)), }
}

///|
/// The string sort.
pub fn TermManager::string_sort(self : TermManager) -> Sort raise Cvc5Error {
  { native: checked(ffi_string_sort(self.native)), }
}

///|
/// The regexp sort.
pub fn TermManager::regexp_sort(self : TermManager) -> Sort raise Cvc5Error {
  { native: checked(ffi_regexp_sort(self.native)), }
}

///|
/// The rounding mode sort.
pub fn TermManager::rounding_mode_sort(
  self : TermManager,
) -> Sort raise Cvc5Error {
  { native: checked(ffi_rounding_mode_sort(self.native)), }
}

///|
/// Create a bit-vector sort with a positive width.
pub fn TermManager::bit_vector_sort(
  self : TermManager,
  width : UInt,
) -> Sort raise Cvc5Error {
  { native: checked(ffi_bit_vector_sort(self.native, width)), }
}

///|
/// Create an array sort with the given index and element sorts.
pub fn TermManager::array_sort(
  self : TermManager,
  index : Sort,
  element : Sort,
) -> Sort raise Cvc5Error {
  {
    native: checked(ffi_array_sort(self.native, index.native, element.native)),
  }
}

///|
/// Create a function sort. The domain must be nonempty.
pub fn TermManager::function_sort(
  self : TermManager,
  domain : ArrayView[Sort],
  codomain : Sort,
) -> Sort raise Cvc5Error {
  {
    native: checked(
      ffi_function_sort(self.native, sort_handles(domain), codomain.native),
    ),
  }
}

///|
/// Create a set sort.
pub fn TermManager::set_sort(
  self : TermManager,
  element : Sort,
) -> Sort raise Cvc5Error {
  { native: checked(ffi_set_sort(self.native, element.native)), }
}

///|
/// Create a sequence sort.
pub fn TermManager::sequence_sort(
  self : TermManager,
  element : Sort,
) -> Sort raise Cvc5Error {
  { native: checked(ffi_sequence_sort(self.native, element.native)), }
}

///|
/// Create a fresh uninterpreted sort with a display name.
/// The name must not contain embedded NUL characters.
pub fn TermManager::uninterpreted_sort(
  self : TermManager,
  symbol : String,
) -> Sort raise Cvc5Error {
  {
    native: checked(ffi_uninterpreted_sort(self.native, @utf8.encode(symbol))),
  }
}

///|
/// Create a fresh free constant. Reusing a name does not reuse a constant.
/// The name must not contain embedded NUL characters.
pub fn TermManager::mk_const(
  self : TermManager,
  sort : Sort,
  symbol : String,
) -> Term raise Cvc5Error {
  {
    native: checked(
      ffi_mk_const(self.native, sort.native, @utf8.encode(symbol)),
    ),
  }
}

///|
/// Create a bound variable for quantifiers and lambdas.
/// The name must not contain embedded NUL characters.
pub fn TermManager::mk_var(
  self : TermManager,
  sort : Sort,
  symbol : String,
) -> Term raise Cvc5Error {
  {
    native: checked(ffi_mk_var(self.native, sort.native, @utf8.encode(symbol))),
  }
}

///|
/// Create a Boolean literal.
pub fn TermManager::mk_boolean(
  self : TermManager,
  value : Bool,
) -> Term raise Cvc5Error {
  { native: checked(ffi_mk_boolean(self.native, value)), }
}

///|
/// Create an integer literal from a signed 64-bit value.
pub fn TermManager::mk_integer(
  self : TermManager,
  value : Int64,
) -> Term raise Cvc5Error {
  { native: checked(ffi_mk_integer(self.native, value)), }
}

///|
/// Create an arbitrary-precision integer from a decimal string.
pub fn TermManager::mk_integer_str(
  self : TermManager,
  value : String,
) -> Term raise Cvc5Error {
  { native: checked(ffi_mk_integer_str(self.native, @utf8.encode(value))), }
}

///|
/// Create an exact real literal from an integer, decimal, or rational such as "1/3".
pub fn TermManager::mk_real(
  self : TermManager,
  value : String,
) -> Term raise Cvc5Error {
  { native: checked(ffi_mk_real(self.native, @utf8.encode(value))), }
}

///|
/// Create a Unicode string literal, preserving embedded NULs. Backslashes are literal.
/// Only Unicode scalar values in the SMT-LIB range U+0000–U+2FFFF are supported.
/// Code points above U+2FFFF and unpaired UTF-16 surrogates raise Cvc5Error.
pub fn TermManager::mk_string(
  self : TermManager,
  value : String,
) -> Term raise Cvc5Error {
  { native: checked(ffi_mk_string(self.native, encode_string_literal(value))), }
}

///|
/// Create a bit vector. Values must fit in the specified positive width.
pub fn TermManager::mk_bit_vector(
  self : TermManager,
  width : UInt,
  value : UInt64,
) -> Term raise Cvc5Error {
  { native: checked(ffi_mk_bit_vector(self.native, width, value)), }
}

///|
/// Create a bit vector of arbitrary width from base 2, 10, or 16 digits.
pub fn TermManager::mk_bit_vector_str(
  self : TermManager,
  width : UInt,
  value : String,
  base? : UInt = 2,
) -> Term raise Cvc5Error {
  {
    native: checked(
      ffi_mk_bit_vector_str(self.native, width, @utf8.encode(value), base),
    ),
  }
}

///|
/// Create an array whose every element has the supplied value.
pub fn TermManager::mk_const_array(
  self : TermManager,
  sort : Sort,
  value : Term,
) -> Term raise Cvc5Error {
  {
    native: checked(ffi_mk_const_array(self.native, sort.native, value.native)),
  }
}

///|
/// Create an expression. cvc5 checks the kind, number of children, and their sorts.
pub fn TermManager::mk_term(
  self : TermManager,
  kind : Kind,
  children : ArrayView[Term],
) -> Term raise Cvc5Error {
  { native: checked(ffi_mk_term(self.native, kind, term_handles(children))), }
}

///|
/// Create an operator with indices, for example BitVectorExtract with [7, 0].
pub fn TermManager::mk_op(
  self : TermManager,
  kind : Kind,
  indices : ArrayView[UInt],
) -> Op raise Cvc5Error {
  {
    native: checked(
      ffi_mk_op(
        self.native,
        kind,
        FixedArray::makei(indices.length(), i => indices[i]),
      ),
    ),
  }
}

///|
/// Apply a previously created operator to its children.
pub fn TermManager::mk_term_from_op(
  self : TermManager,
  op : Op,
  children : ArrayView[Term],
) -> Term raise Cvc5Error {
  {
    native: checked(
      ffi_mk_term_from_op(self.native, op.native, term_handles(children)),
    ),
  }
}
