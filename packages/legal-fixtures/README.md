# Legal fixtures

Worked examples for every legal rule CaseFlow computes, shared by **both**
apps:

| Fixture | Flutter implementation | Web implementation |
| --- | --- | --- |
| `ni_act_court_fee.json` | `apps/mobile/lib/utils/court_fee_rules.dart` | `apps/web/src/legal/niActFee.ts` |
| `ecourts_case_number.json` | `apps/mobile/lib/utils/ecourts_case_number.dart` | `apps/web/src/legal/ecourtsCaseNumber.ts` |

The Flutter test `test/utils/legal_fixtures_test.dart` and the web test
`src/legal/fixtures.test.ts` both run every case in every file. CI runs both.

## Why this exists

The mobile app and the web app are separate codebases. A court fee, a
partition share or a limitation date computed differently on each would be a
real-money, real-deadline error that nobody would notice — the advocate sees
one number, on whichever device they opened.

So a rule is never changed in one place. Change the fixture **first**, then
make both implementations pass it. If only one is updated, the other app's
tests fail, and CI blocks the change.

## Adding a rule

1. Add `<rule>.json` here with its legal basis and the worked examples — the
   boundary cases above all (the exact cap, the slab edge, the rounding).
2. Implement it in both apps.
3. Add a group to both fixture tests.
