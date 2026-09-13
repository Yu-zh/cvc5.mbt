///|
test "CPC proof retrieval selects CPC and supports repeated calls" {
  let tm = @cvc5.TermManager::new()
  let solver = @cvc5.Solver::new(tm)
  solver.set_logic("QF_UF")
  solver.set_option("produce-proofs", "true")
  solver.set_option("proof-format-mode", "none")
  solver.set_option("proof-granularity", "dsl-rewrite")
  let p = tm.mk_const(tm.boolean_sort(), "p")
  solver.assert_formula(p)
  solver.assert_formula(tm.mk_term(Not, [p]))
  assert_true(solver.check_sat() is Unsat)
  let proof = solver.get_proof_cpc()
  assert_true(proof.contains("(declare-const p Bool)"))
  assert_true(proof.contains("(assume @p1 p)"))
  assert_true(proof.contains("(assume @p2 (not p))"))
  assert_true(proof.contains("false :rule contra :premises (@p1 @p2)"))
  for _ in 0..<20 {
    assert_eq(solver.get_proof_cpc(), proof)
  }
  assert_eq(solver.get_option("proof-format-mode"), "none")
}

///|
test "CPC proofs include temporary assumptions and survive new queries" {
  let tm = @cvc5.TermManager::new()
  let solver = @cvc5.Solver::new(tm)
  solver.set_logic("QF_UF")
  solver.set_option("produce-proofs", "true")
  solver.set_option("proof-format-mode", "cpc")
  solver.set_option("incremental", "true")
  let p = tm.mk_const(tm.boolean_sort(), "p")
  let not_p = tm.mk_term(Not, [p])
  solver.assert_formula(p)
  solver.push()
  assert_true(solver.check_sat_assuming([not_p]) is Unsat)
  let first = solver.get_proof_cpc()
  assert_true(first.contains("(assume @p1 p)"), msg=first)
  // Incremental proofs can name (not p) with a shared @t definition and use
  // rewriting to reach false instead of a direct contradiction step.
  assert_true(first.contains("(not p)"), msg=first)
  assert_true(first.contains("(assume @p2 "), msg=first)
  assert_true(first.contains(" false :rule "), msg=first)
  solver.pop()
  assert_true(solver.check_sat() is Sat)
  solver.reset_assertions()
  let q = tm.mk_const(tm.boolean_sort(), "q")
  solver.assert_formula(q)
  solver.assert_formula(tm.mk_term(Not, [q]))
  assert_true(solver.check_sat() is Unsat)
  let second = solver.get_proof_cpc()
  assert_true(second.contains("(declare-const q Bool)"))
  assert_true(second.contains(" false :rule "), msg=second)
  assert_true(first.contains("(declare-const p Bool)"))
  assert_true(!first.contains("(declare-const q Bool)"))
}

///|
fn escaped_proof(symbol : String) -> String raise @cvc5.Cvc5Error {
  let tm = @cvc5.TermManager::new()
  let solver = @cvc5.Solver::new(tm)
  solver.set_logic("QF_UF")
  solver.set_option("produce-proofs", "true")
  let p = tm.mk_const(tm.boolean_sort(), symbol)
  solver.assert_formula(p)
  solver.assert_formula(tm.mk_term(Not, [p]))
  guard solver.check_sat() is Unsat else { abort("Expected Unsat") }
  solver.get_proof_cpc()
}

///|
test "CPC proof strings outlive their solver and other solvers' output" {
  for _ in 0..<20 {
    let first = escaped_proof("kept")
    let second = escaped_proof("later")
    assert_true(first.contains("(declare-const kept Bool)"))
    assert_true(!first.contains("(declare-const later Bool)"))
    assert_true(second.contains("(declare-const later Bool)"))
    assert_true(first.contains("false :rule contra"))
    assert_true(second.contains("false :rule contra"))
  }
}
