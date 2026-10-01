# Legal fixtures

Worked examples for every legal rule CaseFlow computes, shared by **both**
apps:

| Fixture | Flutter implementation | Web implementation |
| --- | --- | --- |
| `ni_act_court_fee.json` | `apps/mobile/lib/utils/court_fee_rules.dart` | `src/legal/niActFee.ts` |
| `ecourts_case_number.json` | `apps/mobile/lib/utils/ecourts_case_number.dart` | `src/legal/ecourtsCaseNumber.ts` |

The web app lives in its own repo,
[caseflow_web_app](https://github.com/AMJATH604/caseflow_web_app), which keeps a
copy of these files in `fixtures/`. **This folder is the master.**

The Flutter test `test/utils/legal_fixtures_test.dart` and the web test
`src/legal/fixtures.test.ts` both run every case in every file, each in its
own repo's CI.

## Why this exists

The mobile app and the web app are separate codebases. A court fee, a
partition share or a limitation date computed differently on each would be a
real-money, real-deadline error that nobody would notice — the advocate sees
one number, on whichever device they opened.

So a rule is never changed in one place. Change the fixture **first**, then
copy it to the web repo's `fixtures/`, and make both implementations pass
it. The two repos' CI runs separately, so the copy step is what keeps them
honest — a fixture changed here and not copied there tests nothing on web.

## Adding a rule

1. Add `<rule>.json` here (and copy it to the web repo's `fixtures/`) with its legal basis and the worked examples — the
   boundary cases above all (the exact cap, the slab edge, the rounding).
2. Implement it in both apps.
3. Add a group to both fixture tests.
