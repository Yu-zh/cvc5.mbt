///|
/// Create a solver. Configure its logic and options before asserting formulas.
pub fn Solver::new(tm : TermManager) -> Solver raise Cvc5Error {
  { native: checked(ffi_solver_new(tm.native)), }
}

///|
pub fn Solver::set_logic(self : Solver, logic : String) -> Unit raise Cvc5Error {
  ignore(checked(ffi_set_logic(self.native, @utf8.encode(logic))))
}

///|
/// Set an upstream cvc5 option, such as "produce-models" or "incremental".
pub fn Solver::set_option(
  self : Solver,
  option : String,
  value : String,
) -> Unit raise Cvc5Error {
  ignore(
    checked(
      ffi_set_option(self.native, @utf8.encode(option), @utf8.encode(value)),
    ),
  )
}

///|
pub fn Solver::get_option(
  self : Solver,
  option : String,
) -> String raise Cvc5Error {
  native_string(ffi_get_option(self.native, @utf8.encode(option)))
}

///|
/// Assert a Boolean formula from the solver's term manager.
pub fn Solver::assert_formula(
  self : Solver,
  formula : Term,
) -> Unit raise Cvc5Error {
  ignore(checked(ffi_assert_formula(self.native, formula.native)))
}

///|
pub fn Solver::check_sat(self : Solver) -> SatResult raise Cvc5Error {
  sat_result(ffi_check_sat(self.native))
}

///|
/// Check satisfiability under temporary assumptions, without asserting them.
pub fn Solver::check_sat_assuming(
  self : Solver,
  assumptions : ArrayView[Term],
) -> SatResult raise Cvc5Error {
  sat_result(ffi_check_sat_assuming(self.native, term_handles(assumptions)))
}

///|
/// Push assertion scopes. Enable the "incremental" option before solving.
pub fn Solver::push(self : Solver, levels? : UInt = 1) -> Unit raise Cvc5Error {
  ignore(checked(ffi_push(self.native, levels)))
}

///|
/// Pop assertion scopes. The C API terminates the process if there are too few.
pub fn Solver::pop(self : Solver, levels? : UInt = 1) -> Unit raise Cvc5Error {
  ignore(checked(ffi_pop(self.native, levels)))
}

///|
pub fn Solver::reset_assertions(self : Solver) -> Unit raise Cvc5Error {
  ignore(checked(ffi_reset_assertions(self.native)))
}

///|
pub fn Solver::get_assertions(self : Solver) -> Array[Term] raise Cvc5Error {
  native_terms(ffi_get_assertions(self.native))
}

///|
/// Requires "produce-unsat-cores" and an unsatisfiable result.
pub fn Solver::get_unsat_core(self : Solver) -> Array[Term] raise Cvc5Error {
  native_terms(ffi_get_unsat_core(self.native))
}

///|
/// Evaluate a term in the current model. Requires "produce-models" and Sat.
pub fn Solver::get_value(self : Solver, term : Term) -> Term raise Cvc5Error {
  { native: checked(ffi_get_value(self.native, term.native)), }
}

///|
/// Evaluate several terms in the current model, preserving order.
pub fn Solver::get_values(
  self : Solver,
  terms : ArrayView[Term],
) -> Array[Term] raise Cvc5Error {
  native_terms(ffi_get_values(self.native, term_handles(terms)))
}

///|
pub fn Solver::simplify(
  self : Solver,
  term : Term,
  apply_substitutions? : Bool = false,
) -> Term raise Cvc5Error {
  {
    native: checked(ffi_simplify(self.native, term.native, apply_substitutions)),
  }
}

///|
/// The version of the linked cvc5 library.
pub fn Solver::version(self : Solver) -> String raise Cvc5Error {
  native_string(ffi_version(self.native))
}
