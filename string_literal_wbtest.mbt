///|
test "decode cvc5 string literal syntax" {
  assert_eq(decode_string_literal(b"\"\""), "")
  assert_eq(
    decode_string_literal(b"\"a\"\"b\\u0000\\u{1F319}\\u{5c}u{41}\""),
    "a\"b\u0000🌙\\u{41}",
  )
  assert_eq(decode_string_literal(b"\"\\u{10ffff}\""), "\u{10ffff}")
}

///|
test "reject malformed cvc5 string literals" {
  for
    text in [
      b"", b"\"", b"abc", b"\"abc", b"\"a\"b\"", b"\"\\\"", b"\"\\n\"", b"\"\\u\"",
      b"\"\\u123\"", b"\"\\u12xz\"", b"\"\\u{}\"", b"\"\\u{41\"", b"\"\\u{xyz}\"",
      b"\"\\u{0000041}\"", b"\"\\u{110000}\"", b"\"\\ud800\"", b"\"\\u{dfff}\"",
      b"\"\xff\"",
    ] {
    let rejected = try {
      ignore(decode_string_literal(text))
      false
    } catch {
      ApiError(_) => true
    }
    assert_true(rejected)
  }
}
