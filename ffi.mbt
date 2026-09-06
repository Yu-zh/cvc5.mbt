///|
#borrow(native)
extern "c" fn ffi_has_error(native : Native) -> Bool = "mbt_cvc5_has_error"

///|
#borrow(native)
extern "c" fn ffi_error(native : Native) -> Bytes = "mbt_cvc5_error"

///|
#borrow(native)
extern "c" fn ffi_string(native : Native) -> Bytes = "mbt_cvc5_string"

///|
#borrow(native)
extern "c" fn ffi_integer(native : Native) -> Int64 = "mbt_cvc5_integer"

///|
#borrow(native)
extern "c" fn ffi_boolean(native : Native) -> Bool = "mbt_cvc5_boolean"

///|
#borrow(native)
extern "c" fn ffi_terms_length(native : Native) -> Int = "mbt_cvc5_terms_length"

///|
#borrow(native)
extern "c" fn ffi_terms_get(native : Native, index : Int) -> Native = "mbt_cvc5_terms_get"

///|
extern "c" fn ffi_tm_new() -> Native = "mbt_cvc5_tm_new"

///|
#borrow(tm)
extern "c" fn ffi_boolean_sort(tm : Native) -> Native = "mbt_cvc5_boolean_sort"

///|
#borrow(tm)
extern "c" fn ffi_integer_sort(tm : Native) -> Native = "mbt_cvc5_integer_sort"

///|
#borrow(tm)
extern "c" fn ffi_real_sort(tm : Native) -> Native = "mbt_cvc5_real_sort"

///|
#borrow(tm)
extern "c" fn ffi_string_sort(tm : Native) -> Native = "mbt_cvc5_string_sort"

///|
#borrow(tm)
extern "c" fn ffi_regexp_sort(tm : Native) -> Native = "mbt_cvc5_regexp_sort"

///|
#borrow(tm)
extern "c" fn ffi_rounding_mode_sort(tm : Native) -> Native = "mbt_cvc5_rounding_mode_sort"

///|
#borrow(tm)
extern "c" fn ffi_bit_vector_sort(tm : Native, width : UInt) -> Native = "mbt_cvc5_bit_vector_sort"

///|
#borrow(tm, index, element)
extern "c" fn ffi_array_sort(
  tm : Native,
  index : Native,
  element : Native,
) -> Native = "mbt_cvc5_array_sort"

///|
#borrow(tm, domain, codomain)
extern "c" fn ffi_function_sort(
  tm : Native,
  domain : FixedArray[Native],
  codomain : Native,
) -> Native = "mbt_cvc5_function_sort"

///|
#borrow(tm, element)
extern "c" fn ffi_set_sort(tm : Native, element : Native) -> Native = "mbt_cvc5_set_sort"

///|
#borrow(tm, element)
extern "c" fn ffi_sequence_sort(tm : Native, element : Native) -> Native = "mbt_cvc5_sequence_sort"

///|
#borrow(tm, symbol)
extern "c" fn ffi_uninterpreted_sort(tm : Native, symbol : Bytes) -> Native = "mbt_cvc5_uninterpreted_sort"

///|
#borrow(tm, sort, symbol)
extern "c" fn ffi_mk_const(
  tm : Native,
  sort : Native,
  symbol : Bytes,
) -> Native = "mbt_cvc5_mk_const"

///|
#borrow(tm, sort, symbol)
extern "c" fn ffi_mk_var(tm : Native, sort : Native, symbol : Bytes) -> Native = "mbt_cvc5_mk_var"

///|
#borrow(tm)
extern "c" fn ffi_mk_boolean(tm : Native, value : Bool) -> Native = "mbt_cvc5_mk_boolean"

///|
#borrow(tm)
extern "c" fn ffi_mk_integer(tm : Native, value : Int64) -> Native = "mbt_cvc5_mk_integer"

///|
#borrow(tm, value)
extern "c" fn ffi_mk_integer_str(tm : Native, value : Bytes) -> Native = "mbt_cvc5_mk_integer_str"

///|
#borrow(tm, value)
extern "c" fn ffi_mk_real(tm : Native, value : Bytes) -> Native = "mbt_cvc5_mk_real"

///|
#borrow(tm, value)
extern "c" fn ffi_mk_string(tm : Native, value : String) -> Native = "mbt_cvc5_mk_string"

///|
#borrow(native)
extern "c" fn ffi_unicode(native : Native) -> String = "mbt_cvc5_unicode"

///|
#borrow(tm)
extern "c" fn ffi_mk_bit_vector(
  tm : Native,
  width : UInt,
  value : UInt64,
) -> Native = "mbt_cvc5_mk_bit_vector"

///|
#borrow(tm, value)
extern "c" fn ffi_mk_bit_vector_str(
  tm : Native,
  width : UInt,
  value : Bytes,
  base : UInt,
) -> Native = "mbt_cvc5_mk_bit_vector_str"

///|
#borrow(tm, sort, value)
extern "c" fn ffi_mk_const_array(
  tm : Native,
  sort : Native,
  value : Native,
) -> Native = "mbt_cvc5_mk_const_array"

///|
#borrow(tm, children)
extern "c" fn ffi_mk_term(
  tm : Native,
  kind : Kind,
  children : FixedArray[Native],
) -> Native = "mbt_cvc5_mk_term"

///|
#borrow(tm, indices)
extern "c" fn ffi_mk_op(
  tm : Native,
  kind : Kind,
  indices : FixedArray[UInt],
) -> Native = "mbt_cvc5_mk_op"

///|
#borrow(tm, op, children)
extern "c" fn ffi_mk_term_from_op(
  tm : Native,
  op : Native,
  children : FixedArray[Native],
) -> Native = "mbt_cvc5_mk_term_from_op"

///|
#borrow(native)
extern "c" fn ffi_describe(native : Native) -> Native = "mbt_cvc5_describe"

///|
#borrow(left, right)
extern "c" fn ffi_equal(left : Native, right : Native) -> Bool = "mbt_cvc5_equal"

///|
#borrow(native)
extern "c" fn ffi_term_kind(native : Native) -> Kind = "mbt_cvc5_term_kind"

///|
#borrow(native)
extern "c" fn ffi_sort_kind(native : Native) -> SortKind = "mbt_cvc5_sort_kind"

///|
#borrow(native)
extern "c" fn ffi_op_kind(native : Native) -> Kind = "mbt_cvc5_op_kind"

///|
#borrow(native)
extern "c" fn ffi_term_sort(native : Native) -> Native = "mbt_cvc5_term_sort"

///|
#borrow(native)
extern "c" fn ffi_term_children(native : Native) -> Native = "mbt_cvc5_term_children"

///|
#borrow(native)
extern "c" fn ffi_term_symbol(native : Native) -> Native = "mbt_cvc5_term_symbol"

///|
#borrow(native)
extern "c" fn ffi_term_boolean_value(native : Native) -> Native = "mbt_cvc5_term_boolean_value"

///|
#borrow(native)
extern "c" fn ffi_term_integer_value(native : Native) -> Native = "mbt_cvc5_term_integer_value"

///|
#borrow(native)
extern "c" fn ffi_term_int64_value(native : Native) -> Native = "mbt_cvc5_term_int64_value"

///|
#borrow(native)
extern "c" fn ffi_term_real_value(native : Native) -> Native = "mbt_cvc5_term_real_value"

///|
#borrow(native)
extern "c" fn ffi_term_string_value(native : Native) -> Native = "mbt_cvc5_term_string_value"

///|
#borrow(native)
extern "c" fn ffi_sort_bit_vector_size(native : Native) -> Native = "mbt_cvc5_sort_bit_vector_size"

///|
#borrow(native)
extern "c" fn ffi_term_has_symbol(native : Native) -> Bool = "mbt_cvc5_term_has_symbol"

///|
#borrow(native)
extern "c" fn ffi_term_bit_vector_value(native : Native, base : UInt) -> Native = "mbt_cvc5_term_bit_vector_value"

///|
#borrow(native, from, to)
extern "c" fn ffi_term_substitute(
  native : Native,
  from : FixedArray[Native],
  to : FixedArray[Native],
) -> Native = "mbt_cvc5_term_substitute"

///|
#borrow(tm)
extern "c" fn ffi_solver_new(tm : Native) -> Native = "mbt_cvc5_solver_new"

///|
#borrow(native, logic)
extern "c" fn ffi_set_logic(native : Native, logic : Bytes) -> Native = "mbt_cvc5_set_logic"

///|
#borrow(native, option, value)
extern "c" fn ffi_set_option(
  native : Native,
  option : Bytes,
  value : Bytes,
) -> Native = "mbt_cvc5_set_option"

///|
#borrow(native, option)
extern "c" fn ffi_get_option(native : Native, option : Bytes) -> Native = "mbt_cvc5_get_option"

///|
#borrow(native, formula)
extern "c" fn ffi_assert_formula(native : Native, formula : Native) -> Native = "mbt_cvc5_assert_formula"

///|
#borrow(native)
extern "c" fn ffi_check_sat(native : Native) -> Native = "mbt_cvc5_check_sat"

///|
#borrow(native, assumptions)
extern "c" fn ffi_check_sat_assuming(
  native : Native,
  assumptions : FixedArray[Native],
) -> Native = "mbt_cvc5_check_sat_assuming"

///|
#borrow(native)
extern "c" fn ffi_result_status(native : Native) -> Int = "mbt_cvc5_result_status"

///|
#borrow(native)
extern "c" fn ffi_unknown_reason(native : Native) -> Bytes = "mbt_cvc5_unknown_reason"

///|
#borrow(native)
extern "c" fn ffi_push(native : Native, levels : UInt) -> Native = "mbt_cvc5_push"

///|
#borrow(native)
extern "c" fn ffi_pop(native : Native, levels : UInt) -> Native = "mbt_cvc5_pop"

///|
#borrow(native)
extern "c" fn ffi_reset_assertions(native : Native) -> Native = "mbt_cvc5_reset_assertions"

///|
#borrow(native)
extern "c" fn ffi_get_assertions(native : Native) -> Native = "mbt_cvc5_get_assertions"

///|
#borrow(native)
extern "c" fn ffi_get_unsat_core(native : Native) -> Native = "mbt_cvc5_get_unsat_core"

///|
#borrow(native)
extern "c" fn ffi_version(native : Native) -> Native = "mbt_cvc5_version"

///|
#borrow(native, term)
extern "c" fn ffi_get_value(native : Native, term : Native) -> Native = "mbt_cvc5_get_value"

///|
#borrow(native, terms)
extern "c" fn ffi_get_values(
  native : Native,
  terms : FixedArray[Native],
) -> Native = "mbt_cvc5_get_values"

///|
#borrow(native, term)
extern "c" fn ffi_simplify(
  native : Native,
  term : Native,
  apply_substitutions : Bool,
) -> Native = "mbt_cvc5_simplify"
