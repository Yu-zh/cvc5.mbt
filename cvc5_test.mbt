///|
test "integer arithmetic and model evaluation" {
  let tm = @cvc5.TermManager::new()
  let solver = @cvc5.Solver::new(tm)
  solver.set_logic("QF_LIA")
  solver.set_option("produce-models", "true")
  assert_eq(solver.get_option("produce-models"), "true")
  assert_true(solver.version().has_prefix("1.3.4"))
  let int = tm.integer_sort()
  let x = tm.mk_const(int, "x")
  let y = tm.mk_const(int, "y")
  solver.assert_formula(tm.mk_term(Equal, [x, tm.mk_integer(7)]))
  solver.assert_formula(
    tm.mk_term(Equal, [tm.mk_term(Add, [x, y]), tm.mk_integer(10)]),
  )
  assert_true(solver.check_sat() is Sat)
  let values = solver.get_values([x, y])
  assert_eq(values.length(), 2)
  assert_eq(values[0].get_int64_value(), 7)
  assert_eq(values[1].get_int64_value(), 3)
  assert_true(solver.get_value(x) == tm.mk_integer(7))
}

///|
test "incremental assertions and temporary assumptions" {
  let tm = @cvc5.TermManager::new()
  let solver = @cvc5.Solver::new(tm)
  solver.set_logic("QF_UF")
  solver.set_option("incremental", "true")
  let p = tm.mk_const(tm.boolean_sort(), "p")
  let not_p = tm.mk_term(Not, [p])
  solver.assert_formula(p)
  solver.push()
  solver.assert_formula(not_p)
  assert_true(solver.check_sat().is_unsat())
  solver.pop()
  assert_true(solver.check_sat().is_sat())
  assert_true(solver.check_sat_assuming([not_p]).is_unsat())
  assert_true(solver.check_sat_assuming([]).is_sat())
  assert_eq(solver.get_assertions().length(), 1)
  solver.reset_assertions()
  assert_eq(solver.get_assertions().length(), 0)
  assert_true(solver.check_sat_assuming([not_p]).is_sat())
}

///|
test "unsat cores retain the original expressions" {
  let tm = @cvc5.TermManager::new()
  let solver = @cvc5.Solver::new(tm)
  solver.set_logic("QF_UF")
  solver.set_option("produce-unsat-cores", "true")
  let p = tm.mk_const(tm.boolean_sort(), "p")
  let not_p = tm.mk_term(Not, [p])
  solver.assert_formula(p)
  solver.assert_formula(not_p)
  assert_true(solver.check_sat() is Unsat)
  let core = solver.get_unsat_core()
  assert_eq(core.length(), 2)
  assert_true(core.contains(p))
  assert_true(core.contains(not_p))
}

///|
test "bit vectors and indexed operators" {
  let tm = @cvc5.TermManager::new()
  let solver = @cvc5.Solver::new(tm)
  let sort = tm.bit_vector_sort(8)
  assert_true(sort.kind() is BitVectorSort)
  assert_eq(sort.bit_vector_size(), 8)
  let a = tm.mk_bit_vector(8, 255)
  let b = tm.mk_bit_vector(8, 1)
  let sum = tm.mk_term(BitVectorAdd, [a, b])
  assert_eq(solver.simplify(sum).get_bit_vector_value(base=10), "0")
  let op = tm.mk_op(BitVectorExtract, [7, 4])
  assert_true(op.kind() is BitVectorExtract)
  let extracted = tm.mk_term_from_op(op, [
    tm.mk_bit_vector_str(8, "a5", base=16),
  ])
  assert_eq(solver.simplify(extracted).get_bit_vector_value(), "1010")
  assert_eq(
    tm
    .mk_bit_vector_str(128, "340282366920938463463374607431768211455", base=10)
    .get_bit_vector_value(base=16),
    "ffffffffffffffffffffffffffffffff",
  )
}

///|
test "array store and select" {
  let tm = @cvc5.TermManager::new()
  let solver = @cvc5.Solver::new(tm)
  let int = tm.integer_sort()
  let sort = tm.array_sort(int, int)
  assert_true(sort.kind() is ArraySort)
  let array = tm.mk_const_array(sort, tm.mk_integer(0))
  let stored = tm.mk_term(Store, [array, tm.mk_integer(2), tm.mk_integer(42)])
  let selected = tm.mk_term(Select, [stored, tm.mk_integer(2)])
  assert_eq(solver.simplify(selected).get_int64_value(), 42)
}

///|
test "exact integers and rationals" {
  let tm = @cvc5.TermManager::new()
  let solver = @cvc5.Solver::new(tm)
  let huge = "1234567890123456789012345678901234567890"
  assert_eq(tm.mk_integer_str(huge).get_integer_value(), huge)
  assert_eq(
    tm.mk_integer(-9223372036854775808).get_int64_value(),
    -9223372036854775808,
  )
  assert_eq(tm.mk_real("1/3").get_real_value(), "1/3")
  let sum = tm.mk_term(Add, [tm.mk_real("1/3"), tm.mk_real("2/3")])
  assert_true(solver.simplify(sum) == tm.mk_real("1"))
}

///|
test "Unicode and embedded NUL string values" {
  let tm = @cvc5.TermManager::new()
  let solver = @cvc5.Solver::new(tm)
  for
    value in [
      "", "hello", "月亮🌙", "a\u0000b", "\u0000", "\u0000a\u0000🌙\u0000",
      "\\u{41}", "\\u0041", "\n\"\\", "\"\"", "\r\t\u007f", "\uffff", "\u{10000}",
    ] {
    assert_eq(tm.mk_string(value).get_string_value(), value)
  }
  let concat = tm.mk_term(StringConcat, [
    tm.mk_string("月"),
    tm.mk_string("亮🌙"),
  ])
  assert_eq(solver.simplify(concat).get_string_value(), "月亮🌙")
  let length = tm.mk_term(StringLength, [tm.mk_string("月亮🌙")])
  assert_eq(solver.simplify(length).get_int64_value(), 3)
  let with_nuls = tm.mk_term(StringConcat, [
    tm.mk_string("a\u0000"),
    tm.mk_string("🌙\u0000b"),
  ])
  assert_eq(solver.simplify(with_nuls).get_string_value(), "a\u0000🌙\u0000b")
  assert_eq(
    solver.simplify(tm.mk_term(StringLength, [with_nuls])).get_int64_value(),
    5,
  )
}

///|
test "uninterpreted functions and quantifiers" {
  let tm = @cvc5.TermManager::new()
  let solver = @cvc5.Solver::new(tm)
  solver.set_logic("ALL")
  let int = tm.integer_sort()
  let function_sort = tm.function_sort([int], int)
  assert_true(function_sort.kind() is FunctionSort)
  let f = tm.mk_const(function_sort, "f")
  let x = tm.mk_var(int, "x")
  let body = tm.mk_term(Equal, [tm.mk_term(ApplyUf, [f, x]), x])
  let forall = tm.mk_term(Forall, [tm.mk_term(VariableList, [x]), body])
  solver.assert_formula(forall)
  let application = tm.mk_term(ApplyUf, [f, tm.mk_integer(0)])
  solver.assert_formula(tm.mk_term(Distinct, [application, tm.mk_integer(0)]))
  assert_true(solver.check_sat() is Unsat)
}

///|
test "term inspection substitution and sort constructors" {
  let tm = @cvc5.TermManager::new()
  let solver = @cvc5.Solver::new(tm)
  let int = tm.integer_sort()
  let x = tm.mk_const(int, "变量🌙x")
  let one = tm.mk_integer(1)
  let term = tm.mk_term(Add, [x, one])
  assert_true(term.kind() is Add)
  assert_true(term.sort() == int)
  assert_true(term.children()[0] == x)
  assert_true(term.children()[1] == one)
  assert_eq(x.symbol(), Some("变量🌙x"))
  assert_true(one.symbol() is None)
  assert_eq(
    solver.simplify(term.substitute([x], [tm.mk_integer(41)])).get_int64_value(),
    42,
  )
  assert_true(tm.boolean_sort().kind() is BooleanSort)
  assert_true(tm.real_sort().kind() is RealSort)
  assert_true(tm.string_sort().kind() is StringSort)
  assert_true(tm.regexp_sort().kind() is ReglanSort)
  assert_true(tm.rounding_mode_sort().kind() is RoundingmodeSort)
  assert_true(tm.set_sort(int).kind() is SetSort)
  assert_true(tm.sequence_sort(int).kind() is SequenceSort)
  assert_true(tm.uninterpreted_sort("A").kind() is UninterpretedSort)
  assert_true(tm.mk_boolean(true).get_boolean_value())
  assert_true(!tm.mk_boolean(false).get_boolean_value())
}

///|
fn expect_api_error(f : () -> Unit raise @cvc5.Cvc5Error) -> Unit raise {
  try f() catch {
    @cvc5.ApiError(message) => assert_true(!message.is_empty())
  } noraise {
    _ => fail("Expected a catchable cvc5 error")
  }
}

///|
test "binding-level checks reject unsafe C arguments" {
  let tm = @cvc5.TermManager::new()
  let solver = @cvc5.Solver::new(tm)
  let integer = tm.mk_integer(1)
  // The C API accepts NUL-terminated strings. Reject truncation here rather
  // than silently turning a different symbol, number, or option into a valid one.
  expect_api_error(() => ignore(tm.mk_const(tm.integer_sort(), "x\u0000y")))
  expect_api_error(() => ignore(tm.mk_var(tm.integer_sort(), "x\u0000y")))
  expect_api_error(() => ignore(tm.uninterpreted_sort("A\u0000B")))
  expect_api_error(() => ignore(tm.mk_integer_str("12\u000034")))
  expect_api_error(() => ignore(tm.mk_real("1\u0000/3")))
  expect_api_error(() => ignore(tm.mk_bit_vector_str(8, "10\u000011")))
  expect_api_error(() => ignore(integer.get_string_value()))
  expect_api_error(() => ignore(integer.substitute([integer], [])))
  expect_api_error(() => ignore(integer.substitute([], [integer])))
  expect_api_error(() => solver.set_logic("QF_LIA\u0000ALL"))
  expect_api_error(() => solver.set_option("produce-models\u0000", "true"))
  expect_api_error(() => solver.set_option("produce-models", "true\u0000false"))
  expect_api_error(() => ignore(solver.get_option("produce-models\u0000")))
  // Invalid upstream operations (wrong arity/sort, invalid options, etc.) are
  // fatal with the C API and are tested separately in child processes.
  assert_true(solver.check_sat() is Sat)
}

///|
test "objects from different managers are rejected" {
  let a = @cvc5.TermManager::new()
  let b = @cvc5.TermManager::new()
  let one = a.mk_integer(1)
  let other = b.mk_integer(1)
  assert_true(one != other)
  assert_true(a.integer_sort() != b.integer_sort())
  expect_api_error(() => ignore(a.mk_term(Equal, [one, other])))
  expect_api_error(() => ignore(a.mk_const(b.integer_sort(), "bad")))
  expect_api_error(() => {
    ignore(a.array_sort(a.integer_sort(), b.integer_sort()))
  })
  expect_api_error(() => {
    ignore(a.function_sort([b.integer_sort()], a.integer_sort()))
  })
  expect_api_error(() => ignore(one.substitute([one], [other])))
  let solver = @cvc5.Solver::new(a)
  expect_api_error(() => solver.assert_formula(b.mk_boolean(true)))
  expect_api_error(() => ignore(solver.check_sat_assuming([b.mk_boolean(true)])))
}

///|
fn escaped_term() -> @cvc5.Term raise @cvc5.Cvc5Error {
  let tm = @cvc5.TermManager::new()
  let solver = @cvc5.Solver::new(tm)
  solver.set_option("produce-models", "true")
  let x = tm.mk_const(tm.integer_sort(), "x")
  solver.assert_formula(tm.mk_term(Equal, [x, tm.mk_integer(42)]))
  ignore(solver.check_sat())
  solver.get_value(x)
}

///|
fn escaped_solver() -> @cvc5.Solver raise @cvc5.Cvc5Error {
  @cvc5.Solver::new(@cvc5.TermManager::new())
}

///|
test "native objects outlive their creating scopes" {
  for _ in 0..<500 {
    let term = escaped_term()
    assert_eq(term.get_int64_value(), 42)
    assert_eq(term.to_string(), "42")
    assert_eq(term.sort().to_string(), "Int")
    assert_true(escaped_solver().check_sat() is Sat)
  }
}

///|
test "resource limits preserve the unknown result and its reason" {
  let tm = @cvc5.TermManager::new()
  let solver = @cvc5.Solver::new(tm)
  solver.set_logic("QF_LIA")
  solver.set_option("rlimit", "1")
  let x = tm.mk_const(tm.integer_sort(), "x")
  solver.assert_formula(tm.mk_term(Gt, [x, tm.mk_integer(0)]))
  let result = solver.check_sat()
  assert_true(result.is_unknown())
  match result {
    Unknown(reason) => assert_true(!reason.is_empty())
    _ => fail("Expected a resource-limited unknown result")
  }
}

///|
test "C API scratch arrays are copied and empty buffers are valid" {
  let tm = @cvc5.TermManager::new()
  let solver = @cvc5.Solver::new(tm)
  solver.set_option("incremental", "true")
  solver.set_option("produce-models", "true")
  let p = tm.mk_const(tm.boolean_sort(), "p")
  let not_p = tm.mk_term(Not, [p])
  solver.assert_formula(p)
  let first = solver.get_assertions()
  assert_true(solver.check_sat() is Sat)
  let model = solver.get_values([p, p])
  assert_eq(solver.get_values([]).length(), 0)
  solver.reset_assertions()
  solver.assert_formula(not_p)
  let second = solver.get_assertions()
  assert_true(solver.check_sat() is Sat)
  let next_model = solver.get_values([p])
  assert_true(first[0] == p)
  assert_true(second[0] == not_p)
  assert_true(model[0].get_boolean_value())
  assert_true(model[1].get_boolean_value())
  assert_true(!next_model[0].get_boolean_value())
  assert_true(p.substitute([], []) == p)
  assert_eq(p.children().length(), 0)
  let op = tm.mk_op(Add, [])
  assert_true(op.kind() is Add)
  let sum = tm.mk_term_from_op(op, [tm.mk_integer(20), tm.mk_integer(22)])
  assert_eq(solver.simplify(sum).get_int64_value(), 42)
  assert_true(tm.mk_term(RegexpNone, []).sort() == tm.regexp_sort())
}

///|
fn escaped_objects() -> (
  @cvc5.Sort,
  @cvc5.Op,
  Array[@cvc5.Term],
  @cvc5.SatResult,
) raise @cvc5.Cvc5Error {
  let tm = @cvc5.TermManager::new()
  let solver = @cvc5.Solver::new(tm)
  let p = tm.mk_const(tm.boolean_sort(), "kept")
  solver.assert_formula(p)
  (
    tm.bit_vector_sort(8),
    tm.mk_op(BitVectorExtract, [7, 4]),
    solver.get_assertions(),
    solver.check_sat(),
  )
}

///|
test "C handles retain their manager and snapshots survive solver destruction" {
  for _ in 0..<200 {
    let (sort, op, terms, result) = escaped_objects()
    assert_eq(sort.bit_vector_size(), 8)
    assert_true(op.kind() is BitVectorExtract)
    assert_true(op == op)
    assert_true(!op.to_string().is_empty())
    assert_eq(terms[0].symbol(), Some("kept"))
    assert_true(result is Sat)
    let held_string = escaped_term().get_integer_value()
    ignore(escaped_term().to_string())
    assert_eq(held_string, "42")
  }
}
