// Runs the web implementations against the worked examples shared with the
// Flutter app (packages/legal-fixtures). The Flutter test
// test/utils/legal_fixtures_test.dart runs the same files, so a rule that
// changes on one platform and not the other fails here or there.
import fee from "@fixtures/ni_act_court_fee.json";
import caseNo from "@fixtures/ecourts_case_number.json";
import { niActFee, niActLegacyFee } from "./niActFee";
import { ecourtsCaseNumber } from "./ecourtsCaseNumber";

describe("NI Act §138 court fee — current (2017)", () => {
  it.each(fee.current.cases)("₹$amount → ₹$fee", ({ amount, fee: expected }) => {
    expect(niActFee(amount)).toBe(expected);
  });
});

describe("NI Act §138 court fee — before 2017", () => {
  it.each(fee.legacy.cases)("₹$amount → ₹$fee", ({ amount, fee: expected }) => {
    expect(niActLegacyFee(amount)).toBe(expected);
  });
});

describe("eCourts case number", () => {
  it.each(caseNo.cases)("$expected", ({ input, expected }) => {
    expect(ecourtsCaseNumber(input as Record<string, unknown>)).toBe(expected);
  });
});

it("every fixture file is exercised", () => {
  expect(fee.current.cases.length).toBeGreaterThan(10);
  expect(fee.legacy.cases.length).toBeGreaterThan(10);
  expect(caseNo.cases.length).toBeGreaterThan(10);
});
