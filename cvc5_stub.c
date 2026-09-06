// MoonBit glue for the public cvc5 C API. Upstream API errors are fatal in
// cvc5 1.3.4; this file does not try to intercept exit() or C++ exceptions.
#include <cvc5/c/cvc5.h>
#include <limits.h>
#include <moonbit.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "kind_checks.inc"

typedef enum {
  N_EMPTY,
  N_MANAGER,
  N_SOLVER,
  N_SORT,
  N_TERM,
  N_OP,
  N_BYTES,
  N_STRING,
  N_INTEGER,
  N_BOOLEAN,
  N_TERMS,
  N_RESULT
} NativeKind;

typedef struct Native Native;
struct Native {
  NativeKind kind;
  // Every derived handle retains the root manager wrapper. There are no
  // back-references, so these explicit MoonBit references cannot form cycles.
  Native *owner;
  const char *error; // Only static messages from binding-level checks.
  union {
    Cvc5TermManager *manager;
    Cvc5 *solver;
    Cvc5Sort sort;
    Cvc5Term term;
    Cvc5Op op;
    moonbit_bytes_t bytes;
    moonbit_string_t string;
    int64_t integer;
    int32_t boolean;
    struct {
      size_t count;
      Cvc5Term *items;
    } terms;
    // Snapshot solver-owned results before releasing their C API handle.
    struct {
      int32_t status;
      moonbit_bytes_t reason;
    } result;
  } value;
};

static void destroy(void *object) {
  Native *n = object;
  switch (n->kind) {
  case N_MANAGER:
    cvc5_term_manager_delete(n->value.manager);
    break;
  case N_SOLVER:
    cvc5_delete(n->value.solver);
    break;
  case N_SORT:
    cvc5_sort_release(n->value.sort);
    break;
  case N_TERM:
    cvc5_term_release(n->value.term);
    break;
  case N_OP:
    cvc5_op_release(n->value.op);
    break;
  case N_BYTES:
    moonbit_decref(n->value.bytes);
    break;
  case N_STRING:
    moonbit_decref(n->value.string);
    break;
  case N_TERMS:
    for (size_t i = 0; i < n->value.terms.count; ++i)
      cvc5_term_release(n->value.terms.items[i]);
    free(n->value.terms.items);
    break;
  case N_RESULT:
    moonbit_decref(n->value.result.reason);
    break;
  default:
    break;
  }
  // Release the cvc5 value BEFORE the manager it belongs to.
  if (n->owner)
    moonbit_decref(n->owner);
  // MoonBit owns the external-object allocation; do not free(n).
}

static Native *root(Native *n) { return n->owner ? n->owner : n; }
static Cvc5TermManager *manager(Native *n) { return root(n)->value.manager; }

static Native *allocate(NativeKind kind, Native *source) {
  Native *n = moonbit_make_external_object(destroy, sizeof(Native));
  *n = (Native){.kind = kind};
  if (source) {
    n->owner = root(source);
    moonbit_incref(n->owner);
  }
  return n;
}

static void *array_allocate(size_t count, size_t item_size) {
  if (count > SIZE_MAX / item_size)
    abort();
  // Some C API functions require a non-NULL pointer even for an empty array.
  void *data = malloc((count ? count : 1) * item_size);
  if (!data)
    abort();
  return data;
}

static Native *binding_error(Native *source, const char *message) {
  Native *n = allocate(N_EMPTY, source);
  n->error = message;
  return n;
}

static const char different_managers[] =
    "Cannot combine objects from different TermManagers";
static const char embedded_nul[] =
    "Embedded NUL is not supported in C API symbols, options, or numeric text";

static bool same_manager(Native *a, Native *b) { return root(a) == root(b); }
static bool has_nul(moonbit_bytes_t s) {
  return memchr(s, 0, (size_t)Moonbit_array_length(s)) != NULL;
}

static moonbit_bytes_t copy_text(const char *text) {
  size_t size = strlen(text);
  if (size > INT32_MAX)
    abort();
  moonbit_bytes_t bytes = moonbit_make_bytes((int32_t)size, 0);
  memcpy(bytes, text, size);
  return bytes;
}

static Native *text_value(Native *source, const char *text) {
  Native *n = allocate(N_BYTES, source);
  // C API text is often thread-local scratch storage: copy it immediately.
  n->value.bytes = copy_text(text);
  return n;
}

// These wrappers adopt the reference returned by a C API call. Copy only
// when creating another wrapper for a reference already owned by this shim.
static Native *term_value(Native *source, Cvc5Term term) {
  Native *n = allocate(N_TERM, source);
  n->value.term = term;
  return n;
}
static Native *sort_value(Native *source, Cvc5Sort sort) {
  Native *n = allocate(N_SORT, source);
  n->value.sort = sort;
  return n;
}
static Native *integer_value(Native *source, int64_t value) {
  Native *n = allocate(N_INTEGER, source);
  n->value.integer = value;
  return n;
}

static Cvc5Term *term_arguments(Native *source, Native *const *items) {
  size_t count = (size_t)Moonbit_array_length(items);
  for (size_t i = 0; i < count; ++i)
    if (!same_manager(source, items[i]))
      return NULL;
  Cvc5Term *terms = array_allocate(count, sizeof(Cvc5Term));
  for (size_t i = 0; i < count; ++i)
    terms[i] = items[i]->value.term;
  return terms; // Borrowed elements; free only this call-scoped array.
}

static Native *term_array(Native *source, const Cvc5Term *terms, size_t count) {
  if (count > INT32_MAX)
    abort();
  Native *n = allocate(N_TERMS, source);
  n->value.terms.count = count;
  n->value.terms.items = array_allocate(count, sizeof(Cvc5Term));
  // The returned C API array is scratch storage, but each element carries an
  // owned reference. Copy the array and adopt each reference exactly once.
  if (count)
    memcpy(n->value.terms.items, terms, count * sizeof(Cvc5Term));
  return n;
}

static Native *result_value(Native *source, Cvc5Result result) {
  Native *n = allocate(N_RESULT, source);
  n->value.result.status = cvc5_result_is_sat(result)     ? 0
                           : cvc5_result_is_unsat(result) ? 1
                                                          : 2;
  n->value.result.reason =
      copy_text(n->value.result.status == 2
                    ? cvc5_unknown_explanation_to_string(
                          cvc5_result_get_unknown_explanation(result))
                    : "");
  cvc5_result_release(result);
  return n;
}

#define FFI MOONBIT_FFI_EXPORT

FFI int32_t mbt_cvc5_has_error(Native *n) { return n->error != NULL; }
FFI moonbit_bytes_t mbt_cvc5_error(Native *n) { return copy_text(n->error); }
FFI moonbit_bytes_t mbt_cvc5_string(Native *n) {
  moonbit_incref(n->value.bytes);
  return n->value.bytes;
}
FFI moonbit_string_t mbt_cvc5_unicode(Native *n) {
  moonbit_incref(n->value.string);
  return n->value.string;
}
FFI int64_t mbt_cvc5_integer(Native *n) { return n->value.integer; }
FFI int32_t mbt_cvc5_boolean(Native *n) { return n->value.boolean; }
FFI int32_t mbt_cvc5_terms_length(Native *n) {
  return (int32_t)n->value.terms.count;
}
FFI Native *mbt_cvc5_terms_get(Native *n, int32_t i) {
  if (i < 0 || (size_t)i >= n->value.terms.count)
    return binding_error(n, "Term array index out of bounds");
  return term_value(n, cvc5_term_copy(n->value.terms.items[i]));
}

FFI Native *mbt_cvc5_tm_new(void) {
  Native *n = allocate(N_MANAGER, NULL);
  n->value.manager = cvc5_term_manager_new();
  return n;
}

// Sort and term construction.
#define TM_SORT(name, function)                                                \
  FFI Native *mbt_cvc5_##name(Native *tm) {                                    \
    return sort_value(tm, function(manager(tm)));                              \
  }
TM_SORT(boolean_sort, cvc5_get_boolean_sort)
TM_SORT(integer_sort, cvc5_get_integer_sort)
TM_SORT(real_sort, cvc5_get_real_sort)
TM_SORT(string_sort, cvc5_get_string_sort)
TM_SORT(regexp_sort, cvc5_get_regexp_sort)
TM_SORT(rounding_mode_sort, cvc5_get_rm_sort)
#undef TM_SORT

FFI Native *mbt_cvc5_bit_vector_sort(Native *tm, uint32_t width) {
  return sort_value(tm, cvc5_mk_bv_sort(manager(tm), width));
}
FFI Native *mbt_cvc5_array_sort(Native *tm, Native *index, Native *element) {
  if (!same_manager(tm, index) || !same_manager(tm, element))
    return binding_error(tm, different_managers);
  return sort_value(tm, cvc5_mk_array_sort(manager(tm), index->value.sort,
                                           element->value.sort));
}
FFI Native *mbt_cvc5_function_sort(Native *tm, Native *const *domain,
                                   Native *codomain) {
  size_t count = (size_t)Moonbit_array_length(domain);
  if (!same_manager(tm, codomain))
    return binding_error(tm, different_managers);
  for (size_t i = 0; i < count; ++i)
    if (!same_manager(tm, domain[i]))
      return binding_error(tm, different_managers);
  Cvc5Sort *sorts = array_allocate(count, sizeof(Cvc5Sort));
  for (size_t i = 0; i < count; ++i)
    sorts[i] = domain[i]->value.sort;
  Cvc5Sort sort =
      cvc5_mk_fun_sort(manager(tm), count, sorts, codomain->value.sort);
  free(sorts);
  return sort_value(tm, sort);
}
FFI Native *mbt_cvc5_set_sort(Native *tm, Native *element) {
  if (!same_manager(tm, element))
    return binding_error(tm, different_managers);
  return sort_value(tm, cvc5_mk_set_sort(manager(tm), element->value.sort));
}
FFI Native *mbt_cvc5_sequence_sort(Native *tm, Native *element) {
  if (!same_manager(tm, element))
    return binding_error(tm, different_managers);
  return sort_value(tm,
                    cvc5_mk_sequence_sort(manager(tm), element->value.sort));
}
FFI Native *mbt_cvc5_uninterpreted_sort(Native *tm, moonbit_bytes_t symbol) {
  if (has_nul(symbol))
    return binding_error(tm, embedded_nul);
  return sort_value(
      tm, cvc5_mk_uninterpreted_sort(manager(tm), (const char *)symbol));
}
FFI Native *mbt_cvc5_mk_const(Native *tm, Native *sort,
                              moonbit_bytes_t symbol) {
  if (!same_manager(tm, sort))
    return binding_error(tm, different_managers);
  if (has_nul(symbol))
    return binding_error(tm, embedded_nul);
  return term_value(
      tm, cvc5_mk_const(manager(tm), sort->value.sort, (const char *)symbol));
}
FFI Native *mbt_cvc5_mk_var(Native *tm, Native *sort, moonbit_bytes_t symbol) {
  if (!same_manager(tm, sort))
    return binding_error(tm, different_managers);
  if (has_nul(symbol))
    return binding_error(tm, embedded_nul);
  return term_value(
      tm, cvc5_mk_var(manager(tm), sort->value.sort, (const char *)symbol));
}
FFI Native *mbt_cvc5_mk_boolean(Native *tm, int32_t value) {
  return term_value(tm, cvc5_mk_boolean(manager(tm), value != 0));
}
FFI Native *mbt_cvc5_mk_integer(Native *tm, int64_t value) {
  return term_value(tm, cvc5_mk_integer_int64(manager(tm), value));
}
FFI Native *mbt_cvc5_mk_integer_str(Native *tm, moonbit_bytes_t value) {
  if (has_nul(value))
    return binding_error(tm, embedded_nul);
  return term_value(tm, cvc5_mk_integer(manager(tm), (const char *)value));
}
FFI Native *mbt_cvc5_mk_real(Native *tm, moonbit_bytes_t value) {
  if (has_nul(value))
    return binding_error(tm, embedded_nul);
  return term_value(tm, cvc5_mk_real(manager(tm), (const char *)value));
}

FFI Native *mbt_cvc5_mk_string(Native *tm, moonbit_string_t value) {
  size_t units = (size_t)Moonbit_array_length(value);
  if (units > (SIZE_MAX - 1) / 10)
    abort();
  size_t capacity = units * 10 + 1;
  char *escaped = array_allocate(capacity, 1);
  size_t used = 0;
  escaped[0] = 0;
  // Encode every scalar, including NUL and backslash, as a Unicode escape.
  // cvc5_mk_string_from_char32 would truncate at an embedded NUL.
  for (size_t i = 0; i < units; ++i) {
    uint32_t code = value[i];
    if (code >= 0xd800 && code <= 0xdbff) {
      if (i + 1 == units || value[i + 1] < 0xdc00 || value[i + 1] > 0xdfff) {
        free(escaped);
        return binding_error(tm, "Unpaired UTF-16 high surrogate");
      }
      code = 0x10000 + ((code - 0xd800) << 10) + (value[++i] - 0xdc00);
    } else if (code >= 0xdc00 && code <= 0xdfff) {
      free(escaped);
      return binding_error(tm, "Unpaired UTF-16 low surrogate");
    }
    int size = snprintf(escaped + used, capacity - used, "\\u{%x}",
                        (unsigned int)code);
    if (size < 0 || (size_t)size >= capacity - used)
      abort();
    used += (size_t)size;
  }
  Cvc5Term term = cvc5_mk_string(manager(tm), escaped, true);
  free(escaped);
  return term_value(tm, term);
}

// Decode cvc5's SMT-LIB string-literal display: doubled quotes and Unicode
// escapes. The C API's UTF-32 getter has no length, so it cannot distinguish
// an embedded NUL from the end. A NULL output performs the sizing pass.
static int32_t decode_string_literal(const char *text, uint16_t *output) {
  size_t size = strlen(text), used = 0;
  if (size < 2 || text[0] != '"' || text[size - 1] != '"')
    return -1;
  for (size_t i = 1; i < size - 1;) {
    uint32_t code = (unsigned char)text[i++];
    if (code == '"') {
      if (i >= size - 1 || text[i++] != '"')
        return -1;
    } else if (code == '\\') {
      if (i >= size - 1 || text[i++] != 'u')
        return -1;
      bool braced = i < size - 1 && text[i] == '{';
      if (braced)
        ++i;
      unsigned int digits = 0;
      code = 0;
      while (i < size - 1 && (braced ? text[i] != '}' : digits < 4)) {
        unsigned char c = (unsigned char)text[i++];
        unsigned int digit;
        if (c >= '0' && c <= '9')
          digit = c - '0';
        else if (c >= 'a' && c <= 'f')
          digit = c - 'a' + 10;
        else if (c >= 'A' && c <= 'F')
          digit = c - 'A' + 10;
        else
          return -1;
        if (++digits > 6)
          return -1;
        code = code * 16 + digit;
      }
      if (braced) {
        if (!digits || i >= size - 1 || text[i++] != '}')
          return -1;
      } else if (digits != 4)
        return -1;
    } else if (code > 0x7f) {
      // The pinned cvc5 printer escapes non-ASCII characters.
      return -1;
    }
    if (code > 0x10ffff || (code >= 0xd800 && code <= 0xdfff))
      return -1;
    size_t width = code > 0xffff ? 2 : 1;
    if (used > INT32_MAX - width)
      return -1;
    if (output) {
      if (width == 2) {
        output[used] = (uint16_t)(0xd800 + ((code - 0x10000) >> 10));
        output[used + 1] = (uint16_t)(0xdc00 + ((code - 0x10000) & 0x3ff));
      } else
        output[used] = (uint16_t)code;
    }
    used += width;
  }
  return (int32_t)used;
}

FFI Native *mbt_cvc5_term_string_value(Native *n) {
  if (!cvc5_term_is_string_value(n->value.term))
    return binding_error(n, "Term is not a string literal");
  const char *text = cvc5_term_to_string(n->value.term);
  int32_t length = decode_string_literal(text, NULL);
  if (length < 0)
    return binding_error(n, "Cannot decode cvc5 string literal");
  Native *result = allocate(N_STRING, n);
  result->value.string = moonbit_make_string(length, 0);
  if (decode_string_literal(text, result->value.string) != length)
    abort();
  return result;
}

FFI Native *mbt_cvc5_mk_bit_vector(Native *tm, uint32_t width, uint64_t value) {
  return term_value(tm, cvc5_mk_bv_uint64(manager(tm), width, value));
}
FFI Native *mbt_cvc5_mk_bit_vector_str(Native *tm, uint32_t width,
                                       moonbit_bytes_t value, uint32_t base) {
  if (has_nul(value))
    return binding_error(tm, embedded_nul);
  return term_value(tm,
                    cvc5_mk_bv(manager(tm), width, (const char *)value, base));
}
FFI Native *mbt_cvc5_mk_const_array(Native *tm, Native *sort, Native *value) {
  if (!same_manager(tm, sort) || !same_manager(tm, value))
    return binding_error(tm, different_managers);
  return term_value(tm, cvc5_mk_const_array(manager(tm), sort->value.sort,
                                            value->value.term));
}
FFI Native *mbt_cvc5_mk_term(Native *tm, int32_t kind,
                             Native *const *children) {
  Cvc5Term *terms = term_arguments(tm, children);
  if (!terms)
    return binding_error(tm, different_managers);
  Cvc5Term term = cvc5_mk_term(manager(tm), (Cvc5Kind)(kind - 2),
                               (size_t)Moonbit_array_length(children), terms);
  free(terms);
  return term_value(tm, term);
}
FFI Native *mbt_cvc5_mk_op(Native *tm, int32_t kind, uint32_t *indices) {
  Native *n = allocate(N_OP, tm);
  n->value.op = cvc5_mk_op(manager(tm), (Cvc5Kind)(kind - 2),
                           (size_t)Moonbit_array_length(indices), indices);
  return n;
}
FFI Native *mbt_cvc5_mk_term_from_op(Native *tm, Native *op,
                                     Native *const *children) {
  if (!same_manager(tm, op))
    return binding_error(tm, different_managers);
  Cvc5Term *terms = term_arguments(tm, children);
  if (!terms)
    return binding_error(tm, different_managers);
  Cvc5Term term = cvc5_mk_term_from_op(
      manager(tm), op->value.op, (size_t)Moonbit_array_length(children), terms);
  free(terms);
  return term_value(tm, term);
}

// Inspection and substitution.
FFI Native *mbt_cvc5_describe(Native *n) {
  switch (n->kind) {
  case N_TERM:
    return text_value(n, cvc5_term_to_string(n->value.term));
  case N_SORT:
    return text_value(n, cvc5_sort_to_string(n->value.sort));
  case N_OP:
    return text_value(n, cvc5_op_to_string(n->value.op));
  default:
    return binding_error(n, "Object is not a term, sort, or operator");
  }
}
FFI int32_t mbt_cvc5_equal(Native *a, Native *b) {
  if (!same_manager(a, b) || a->kind != b->kind)
    return 0;
  switch (a->kind) {
  case N_TERM:
    return cvc5_term_is_equal(a->value.term, b->value.term);
  case N_SORT:
    return cvc5_sort_is_equal(a->value.sort, b->value.sort);
  case N_OP:
    return cvc5_op_is_equal(a->value.op, b->value.op);
  default:
    return a == b;
  }
}
FFI int32_t mbt_cvc5_term_kind(Native *n) {
  return (int32_t)cvc5_term_get_kind(n->value.term) + 2;
}
FFI int32_t mbt_cvc5_sort_kind(Native *n) {
  return (int32_t)cvc5_sort_get_kind(n->value.sort) + 2;
}
FFI int32_t mbt_cvc5_op_kind(Native *n) {
  return (int32_t)cvc5_op_get_kind(n->value.op) + 2;
}
FFI Native *mbt_cvc5_term_sort(Native *n) {
  return sort_value(n, cvc5_term_get_sort(n->value.term));
}
FFI Native *mbt_cvc5_term_children(Native *n) {
  size_t count = cvc5_term_get_num_children(n->value.term);
  if (count > INT32_MAX)
    abort();
  Native *result = allocate(N_TERMS, n);
  result->value.terms.count = count;
  result->value.terms.items = array_allocate(count, sizeof(Cvc5Term));
  for (size_t i = 0; i < count; ++i)
    result->value.terms.items[i] = cvc5_term_get_child(n->value.term, i);
  return result;
}
FFI int32_t mbt_cvc5_term_has_symbol(Native *n) {
  return cvc5_term_has_symbol(n->value.term);
}
FFI Native *mbt_cvc5_term_symbol(Native *n) {
  return text_value(n, cvc5_term_get_symbol(n->value.term));
}
FFI Native *mbt_cvc5_term_boolean_value(Native *n) {
  Native *result = allocate(N_BOOLEAN, n);
  result->value.boolean = cvc5_term_get_boolean_value(n->value.term);
  return result;
}
FFI Native *mbt_cvc5_term_integer_value(Native *n) {
  return text_value(n, cvc5_term_get_integer_value(n->value.term));
}
FFI Native *mbt_cvc5_term_int64_value(Native *n) {
  return integer_value(n, cvc5_term_get_int64_value(n->value.term));
}
FFI Native *mbt_cvc5_term_real_value(Native *n) {
  return text_value(n, cvc5_term_get_real_value(n->value.term));
}
FFI Native *mbt_cvc5_term_bit_vector_value(Native *n, uint32_t base) {
  return text_value(n, cvc5_term_get_bv_value(n->value.term, base));
}
FFI Native *mbt_cvc5_sort_bit_vector_size(Native *n) {
  return integer_value(n, cvc5_sort_bv_get_size(n->value.sort));
}
FFI Native *mbt_cvc5_term_substitute(Native *n, Native *const *from,
                                     Native *const *to) {
  size_t count = (size_t)Moonbit_array_length(from);
  // The C API takes one length for both arrays. Reject a mismatch before it
  // could read past the shorter array, independent of upstream error handling.
  if (count != (size_t)Moonbit_array_length(to))
    return binding_error(n, "Substitution arrays must have the same length");
  Cvc5Term *old = term_arguments(n, from);
  if (!old)
    return binding_error(n, different_managers);
  Cvc5Term *replacement = term_arguments(n, to);
  if (!replacement) {
    free(old);
    return binding_error(n, different_managers);
  }
  Cvc5Term term =
      cvc5_term_substitute_terms(n->value.term, count, old, replacement);
  free(old);
  free(replacement);
  return term_value(n, term);
}

// Solver operations.
FFI Native *mbt_cvc5_solver_new(Native *tm) {
  Native *n = allocate(N_SOLVER, tm);
  n->value.solver = cvc5_new(manager(tm));
  return n;
}
FFI Native *mbt_cvc5_set_logic(Native *n, moonbit_bytes_t logic) {
  if (has_nul(logic))
    return binding_error(n, embedded_nul);
  cvc5_set_logic(n->value.solver, (const char *)logic);
  return allocate(N_EMPTY, n);
}
FFI Native *mbt_cvc5_set_option(Native *n, moonbit_bytes_t option,
                                moonbit_bytes_t value) {
  if (has_nul(option) || has_nul(value))
    return binding_error(n, embedded_nul);
  cvc5_set_option(n->value.solver, (const char *)option, (const char *)value);
  return allocate(N_EMPTY, n);
}
FFI Native *mbt_cvc5_get_option(Native *n, moonbit_bytes_t option) {
  if (has_nul(option))
    return binding_error(n, embedded_nul);
  return text_value(n, cvc5_get_option(n->value.solver, (const char *)option));
}
FFI Native *mbt_cvc5_assert_formula(Native *n, Native *formula) {
  if (!same_manager(n, formula))
    return binding_error(n, different_managers);
  cvc5_assert_formula(n->value.solver, formula->value.term);
  return allocate(N_EMPTY, n);
}
FFI Native *mbt_cvc5_check_sat(Native *n) {
  return result_value(n, cvc5_check_sat(n->value.solver));
}
FFI Native *mbt_cvc5_check_sat_assuming(Native *n, Native *const *assumptions) {
  Cvc5Term *terms = term_arguments(n, assumptions);
  if (!terms)
    return binding_error(n, different_managers);
  Cvc5Result result = cvc5_check_sat_assuming(
      n->value.solver, (size_t)Moonbit_array_length(assumptions), terms);
  free(terms);
  return result_value(n, result);
}
FFI int32_t mbt_cvc5_result_status(Native *n) { return n->value.result.status; }
FFI moonbit_bytes_t mbt_cvc5_unknown_reason(Native *n) {
  moonbit_incref(n->value.result.reason);
  return n->value.result.reason;
}
FFI Native *mbt_cvc5_push(Native *n, uint32_t levels) {
  cvc5_push(n->value.solver, levels);
  return allocate(N_EMPTY, n);
}
FFI Native *mbt_cvc5_pop(Native *n, uint32_t levels) {
  cvc5_pop(n->value.solver, levels);
  return allocate(N_EMPTY, n);
}
FFI Native *mbt_cvc5_reset_assertions(Native *n) {
  cvc5_reset_assertions(n->value.solver);
  return allocate(N_EMPTY, n);
}
FFI Native *mbt_cvc5_get_assertions(Native *n) {
  size_t count;
  const Cvc5Term *terms = cvc5_get_assertions(n->value.solver, &count);
  return term_array(n, terms, count);
}
FFI Native *mbt_cvc5_get_unsat_core(Native *n) {
  size_t count;
  const Cvc5Term *terms = cvc5_get_unsat_core(n->value.solver, &count);
  return term_array(n, terms, count);
}
FFI Native *mbt_cvc5_get_value(Native *n, Native *term) {
  if (!same_manager(n, term))
    return binding_error(n, different_managers);
  return term_value(n, cvc5_get_value(n->value.solver, term->value.term));
}
FFI Native *mbt_cvc5_get_values(Native *n, Native *const *items) {
  Cvc5Term *terms = term_arguments(n, items);
  if (!terms)
    return binding_error(n, different_managers);
  size_t count;
  const Cvc5Term *values = cvc5_get_values(
      n->value.solver, (size_t)Moonbit_array_length(items), terms, &count);
  Native *result = term_array(n, values, count);
  free(terms);
  return result;
}
FFI Native *mbt_cvc5_simplify(Native *n, Native *term,
                              int32_t apply_substitutions) {
  if (!same_manager(n, term))
    return binding_error(n, different_managers);
  return term_value(n, cvc5_simplify(n->value.solver, term->value.term,
                                     apply_substitutions != 0));
}
FFI Native *mbt_cvc5_version(Native *n) {
  return text_value(n, cvc5_get_version(n->value.solver));
}
