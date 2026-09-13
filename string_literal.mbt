///|
// The C API accepts NUL-terminated text. Escape every scalar so embedded NULs
// and literal backslashes survive cvc5's escape processing.
fn encode_string_literal(value : String) -> Bytes raise Cvc5Error {
  let output = StringBuilder()
  for ch in value {
    let code = ch.to_int()
    if code is (0xd800..=0xdbff) {
      raise ApiError("Unpaired UTF-16 high surrogate")
    }
    if code is (0xdc00..=0xdfff) {
      raise ApiError("Unpaired UTF-16 low surrogate")
    }
    if code > 0x2ffff {
      raise ApiError(
        "String literal code point exceeds the SMT-LIB limit U+2FFFF",
      )
    }
    output.write_string("\\u{")
    output.write_string(code.to_string(radix=16))
    output.write_char('}')
  }
  @utf8.encode(output.to_string())
}

///|
fn decode_string_codepoint(digits : BytesView) -> Char raise Cvc5Error {
  guard !digits.is_empty() && digits.length() <= 6 else {
    raise ApiError("Cannot decode cvc5 string literal")
  }
  let mut code = 0
  for digit in digits {
    let value = match digit {
      b'0'..=b'9' => digit.to_int() - 0x30
      b'a'..=b'f' => digit.to_int() - 0x61 + 10
      b'A'..=b'F' => digit.to_int() - 0x41 + 10
      _ => raise ApiError("Cannot decode cvc5 string literal")
    }
    code = code * 16 + value
  }
  guard code.to_char() is Some(ch) else {
    raise ApiError("Cannot decode cvc5 string literal")
  }
  ch
}

///|
// Decode the pinned cvc5 printer's ASCII string-literal syntax. The native
// UTF-32 getter has no length, so reading its output would lose embedded NULs.
fn decode_string_literal(text : BytesView) -> String raise Cvc5Error {
  guard text is [b'"', .. body, b'"'] else {
    raise ApiError("Cannot decode cvc5 string literal")
  }
  let output = StringBuilder()
  for remaining = body {
    match remaining {
      [] => break output.to_string()
      [b'"', b'"', .. rest] => {
        output.write_char('"')
        continue rest
      }
      [b'\\', b'u', b'{', .. rest] => {
        guard rest.find(b"}") is Some(end) else {
          raise ApiError("Cannot decode cvc5 string literal")
        }
        output.write_char(decode_string_codepoint(rest[:end]))
        continue rest[end + 1:]
      }
      [b'\\', b'u', .. rest] if rest.length() >= 4 => {
        output.write_char(decode_string_codepoint(rest[:4]))
        continue rest[4:]
      }
      [byte, .. rest] if byte <= 0x7f && byte != b'\\' && byte != b'"' => {
        output.write_char(byte.to_int().to_char().unwrap())
        continue rest
      }
      _ => raise ApiError("Cannot decode cvc5 string literal")
    }
  }
}
