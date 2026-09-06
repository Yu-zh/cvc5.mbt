///|
pub fn Sort::to_string(self : Sort) -> String {
  try! native_string(ffi_describe(self.native))
}

///|
pub impl Show for Sort with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
pub extend Sort with Show::{output}

///|
pub impl Eq for Sort with fn equal(self, other) {
  ffi_equal(self.native, other.native)
}

///|
pub extend Sort with Eq::{equal, not_equal}

///|
pub fn Sort::kind(self : Sort) -> SortKind {
  ffi_sort_kind(self.native)
}

///|
/// Read the width of a bit-vector sort. The C API terminates the process for
/// other sorts.
pub fn Sort::bit_vector_size(self : Sort) -> UInt raise Cvc5Error {
  ffi_integer(checked(ffi_sort_bit_vector_size(self.native)))
  .to_int()
  .reinterpret_as_uint()
}

///|
pub fn Op::to_string(self : Op) -> String {
  try! native_string(ffi_describe(self.native))
}

///|
pub impl Show for Op with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
pub extend Op with Show::{output}

///|
pub impl Eq for Op with fn equal(self, other) {
  ffi_equal(self.native, other.native)
}

///|
pub extend Op with Eq::{equal, not_equal}

///|
pub fn Op::kind(self : Op) -> Kind {
  ffi_op_kind(self.native)
}
