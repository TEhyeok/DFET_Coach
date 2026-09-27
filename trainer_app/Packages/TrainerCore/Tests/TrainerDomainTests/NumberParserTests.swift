import XCTest
@testable import TrainerDomain

/// DF-127 (TC-127-07, V1-09 §10.1): trainer number input. Blank is unmeasured, a comma is the decimal point, anything
/// else that is not plain digits is refused rather than guessed.
final class NumberParserTests: XCTestCase {
  func testTable() {
    let cases: [(text: String, digits: Int?, expected: NumberParser.Result, line: UInt)] = [
      ("62.4", 1, .value(62.4), #line),
      ("62,4", 1, .value(62.4), #line),
      ("  62,4  ", 1, .value(62.4), #line),
      ("\u{3000}62.4\u{3000}", 1, .value(62.4), #line),  // full-width space
      ("\t62\n", 1, .value(62), #line),
      ("0", 1, .value(0), #line),
      ("600", 1, .value(600), #line),
      ("007.5", 1, .value(7.5), #line),
      ("", 1, .empty, #line),
      ("   ", 1, .empty, #line),
      ("\u{3000}", 1, .empty, #line),
      ("62.45", 1, .invalid, #line),  // second decimal is refused, not rounded (ASM-09-21)
      ("62.45", 2, .value(62.45), #line),
      ("62.45", nil, .value(62.45), #line),
      ("45", 0, .value(45), #line),
      ("45.5", 0, .invalid, #line),
      ("-3", 1, .invalid, #line),
      ("+3", 1, .invalid, #line),
      ("6e1", 1, .invalid, #line),
      ("1,234.5", 1, .invalid, #line),
      ("1.2.3", 1, .invalid, #line),
      (".5", 1, .invalid, #line),
      ("5.", 1, .invalid, #line),
      ("5,", 1, .invalid, #line),
      ("6 2", 1, .invalid, #line),
      ("62kg", 1, .invalid, #line),
      ("45도 정도", nil, .invalid, #line),
      ("좋음", nil, .invalid, #line),
      ("4+", nil, .invalid, #line),
      ("NaN", nil, .invalid, #line),
      ("inf", nil, .invalid, #line),
      ("０６２", 1, .invalid, #line),  // full-width digits are not ASCII digits
      ("٦٢", 1, .invalid, #line),  // Arabic-Indic digits
      (String(repeating: "9", count: 400), nil, .invalid, #line),  // overflows to infinity
    ]
    for c in cases {
      XCTAssertEqual(NumberParser.parse(c.text, maxFractionDigits: c.digits), c.expected, "\(c.text)", line: c.line)
    }
  }

  func testDoubleConvenienceIsNilForBlankAndGarbage() {
    XCTAssertEqual(NumberParser.double("62,4"), 62.4)
    XCTAssertNil(NumberParser.double(""))
    XCTAssertNil(NumberParser.double("abc"))
    XCTAssertEqual(NumberParser.double("62.45"), 62.45, "no fraction limit by default")
  }

  func testDisplayTextIsLocaleFreeAndShort() {
    XCTAssertEqual(NumberParser.displayText(600), "600")
    XCTAssertEqual(NumberParser.displayText(0.1), "0.1")
    XCTAssertEqual(NumberParser.displayText(0), "0")
    XCTAssertEqual(NumberParser.displayText(22.9), "22.9")
    XCTAssertEqual(NumberParser.displayText(100), "100")
  }
}
