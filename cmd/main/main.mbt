///|
/// Solve x + y = 10 with x > 0 and y > 0.
fn main raise {
  let tm = @cvc5.TermManager::new()
  let solver = @cvc5.Solver::new(tm)
  solver.set_logic("QF_LIA")
  solver.set_option("produce-models", "true")
  let int = tm.integer_sort()
  let x = tm.mk_const(int, "x")
  let y = tm.mk_const(int, "y")
  let zero = tm.mk_integer(0)
  let sum = tm.mk_term(Add, [x, y])
  solver.assert_formula(tm.mk_term(Equal, [sum, tm.mk_integer(10)]))
  solver.assert_formula(tm.mk_term(Gt, [x, zero]))
  solver.assert_formula(tm.mk_term(Gt, [y, zero]))
  println("cvc5 \{solver.version()}")
  match solver.check_sat() {
    Sat =>
      println("sat: x = \{solver.get_value(x)}, y = \{solver.get_value(y)}")
    Unsat => println("unsat")
    Unknown(reason) => println("unknown: \{reason}")
  }
}
