// Run only through scripts/test-c-api-errors.js. Each case must terminate inside
// the upstream C API; the script isolates cases in separate child processes.

///|
test "zero bit-vector width" {
  ignore(@cvc5.TermManager::new().bit_vector_sort(0))
}

///|
test "invalid integer" {
  ignore(@cvc5.TermManager::new().mk_integer_str("invalid"))
}

///|
test "zero rational denominator" {
  ignore(@cvc5.TermManager::new().mk_real("1/0"))
}

///|
test "wrong term sort" {
  let tm = @cvc5.TermManager::new()
  ignore(tm.mk_term(Not, [tm.mk_integer(1)]))
}

///|
test "wrong term arity" {
  let tm = @cvc5.TermManager::new()
  ignore(tm.mk_term(Equal, [tm.mk_integer(1)]))
}

///|
test "non-Boolean assertion" {
  let tm = @cvc5.TermManager::new()
  @cvc5.Solver::new(tm).assert_formula(tm.mk_integer(1))
}

///|
test "wrong literal getter" {
  ignore(@cvc5.TermManager::new().mk_integer(1).get_boolean_value())
}

///|
test "wrong sort getter" {
  ignore(@cvc5.TermManager::new().integer_sort().bit_vector_size())
}

///|
test "Int64 overflow" {
  ignore(
    @cvc5.TermManager::new()
    .mk_integer_str("9223372036854775808")
    .get_int64_value(),
  )
}

///|
test "invalid option" {
  @cvc5.Solver::new(@cvc5.TermManager::new()).set_option(
    "not-a-cvc5-option", "true",
  )
}

///|
test "model before solving" {
  let tm = @cvc5.TermManager::new()
  ignore(@cvc5.Solver::new(tm).get_value(tm.mk_integer(1)))
}

///|
test "pop without a scope" {
  @cvc5.Solver::new(@cvc5.TermManager::new()).pop()
}

///|
test "proofs not enabled" {
  let tm = @cvc5.TermManager::new()
  let solver = @cvc5.Solver::new(tm)
  solver.assert_formula(tm.mk_boolean(false))
  assert_true(solver.check_sat() is Unsat)
  ignore(solver.get_proof_cpc())
}

///|
test "proof before solving" {
  let solver = @cvc5.Solver::new(@cvc5.TermManager::new())
  solver.set_option("produce-proofs", "true")
  ignore(solver.get_proof_cpc())
}

///|
test "proof after sat" {
  let solver = @cvc5.Solver::new(@cvc5.TermManager::new())
  solver.set_option("produce-proofs", "true")
  assert_true(solver.check_sat() is Sat)
  ignore(solver.get_proof_cpc())
}

///|
test "proof after resetting assertions" {
  let tm = @cvc5.TermManager::new()
  let solver = @cvc5.Solver::new(tm)
  solver.set_option("produce-proofs", "true")
  solver.set_option("incremental", "true")
  solver.assert_formula(tm.mk_boolean(false))
  assert_true(solver.check_sat() is Unsat)
  solver.reset_assertions()
  ignore(solver.get_proof_cpc())
}
