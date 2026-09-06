///|
// No native linker flags or build hook here: they must propagate from cvc5.
// fn main raise {
//   let tm = @cvc5.TermManager::new()
//   let solver = @cvc5.Solver::new(tm)
//   solver.set_option("produce-models", "true")
//   let x = tm.mk_const(tm.integer_sort(), "x")
//   solver.assert_formula(tm.mk_term(Equal, [x, tm.mk_integer(42)]))
//   assert_true(solver.check_sat().is_sat())
//   assert_eq(solver.get_value(x).get_int64_value(), 42)
//   println("consumer: sat, x = 42")
// }

fn main raise {
  let tm = @cvc5.TermManager::new()
  let solver = @cvc5.Solver::new(tm)
  solver.set_logic("ALL")
  solver.set_option("produce-models", "true")
  solver.set_option("produce-unsat-cores", "true")
  let real_sort = tm.real_sort()
  // let int_sort = tm.integer_sort()
  let x = tm.mk_const(real_sort, "x")
  let y = tm.mk_const(real_sort, "y")
  // let a = tm.mk_const(int_sort, "a")
  // let b = tm.mk_const(int_sort, "b")

  let x_plus_y = tm.mk_term(Add, [x, y])
  let zero = tm.mk_real("0")
  let one = tm.mk_real("1")
  let c1 = tm.mk_term(Lt, [zero, x])
  let c2 = tm.mk_term(Lt, [zero, y])
  let c3 = tm.mk_term(Lt, [x_plus_y, one])
  let c4 = tm.mk_term(Leq, [x, y])
  solver.assert_formula(c1)
  solver.assert_formula(c2)
  solver.assert_formula(c3)
  solver.assert_formula(c4)
  let r = solver.check_sat()
  println("result: \{r.is_sat()}")
  let x_val = solver.get_value(x).get_real_value()
  let y_val = solver.get_value(y).get_real_value()
  println("x_val: \{x_val}")
  println("y_val: \{y_val}")
}
