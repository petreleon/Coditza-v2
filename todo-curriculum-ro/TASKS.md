# Registrul autoritativ al taskurilor curriculare

Acesta este singurul index de status pentru planul curricular.

Statusuri permise: `next`, `not started`, `in progress`, `needs revalidation`,
`blocked`, `complete`, `not applicable`. Numai un rând poate fi `next` sau
`in progress`.

| ID | Mod | Prerechizit dur | Owner / scope permis | Dovadă minimă | Status |
| --- | --- | --- | --- | --- | --- |
| CURR-PLAN-001 | review | plan livrat | [roadmap](03-execution/00-roadmap.md) — decizii numai | acceptare/modificări înregistrate | next |
| CURR-PLAN-002 | review | CURR-PLAN-001 | [roadmap](03-execution/00-roadmap.md) — autorizare numai | cerere explicită de redactare | blocked |
| CURR-STD-001 | review/local | CURR-PLAN-002 | [standarde](00-control/02-limba-terminologie-si-stil.md) | standarde + toolchain autor + politică chei/WASM | not started |
| CURR-WASM-001 | review/local | CURR-STD-001 + Coditza G-WASM | [contract WASM](00-control/05-contract-verificare-python-wasm.md) | profil lock-uit + scheme/fixture-uri + paritate server/local WASM | not started |
| CURR-FORMAT-001 | local | CURR-WASM-001 + Coditza backend G5 | [contract capitol](00-control/03-contractul-unui-capitol.md) | scheme/validator/fixture-uri, inclusiv `python_code`, fără conținut | not started |
| M1-OUTLINE-001 | author | CURR-FORMAT-001 | [harta modulului](01-modul-01-arhitectura-python/00-harta-modulului.md) | ordine/obiective/checkpointuri aprobate | not started |
| M1-EXAMPLE-001 | author | M1-OUTLINE-001 | [Study Tracker](01-modul-01-arhitectura-python/01-proiectul-study-tracker.md) | specificație și teste planificate | not started |
| M1-BASELINE-001 | author/local | M1-EXAMPLE-001 + CURR-WASM-001 | [Study Tracker](01-modul-01-arhitectura-python/01-proiectul-study-tracker.md) | C00 reconstruibil + pachet `python_code` trecut server-side WASM | not started |
| M1-GLOSSARY-001 | author | outline + example | [glosar](01-modul-01-arhitectura-python/02-glosar-planificat.md) | termeni canonici aprobați | not started |
| M1-C01-001 | author/local | M1-GLOSSARY-001 + M1-BASELINE-001 + CG1 | [Capitolul 1](01-modul-01-arhitectura-python/03-capitol-01-nevoia-de-arhitectura.md) | pachet complet + CG2-C01 | not started |
| M1-C02-001 | author/local | M1-C01-001 + CG2-C01 | [Capitolul 2](01-modul-01-arhitectura-python/04-capitol-02-module-si-dependente.md) | pachet complet + CG2-C02 | not started |
| M1-C03-001 | author/local | M1-C02-001 + CG2-C02 | [Capitolul 3](01-modul-01-arhitectura-python/05-capitol-03-modelarea-domeniului.md) | pachet complet + CG2-C03 | not started |
| M1-C04-001 | author/local | M1-C03-001 + CG2-C03 | [Capitolul 4](01-modul-01-arhitectura-python/06-capitol-04-cazuri-de-utilizare.md) | pachet complet + CG2-C04 | not started |
| M1-C05-001 | author/local | M1-C04-001 + CG2-C04 | [Capitolul 5](01-modul-01-arhitectura-python/07-capitol-05-inversarea-dependentelor.md) | pachet complet + CG2-C05 | not started |
| M1-C06-001 | author/local | M1-C05-001 + CG2-C05 | [Capitolul 6](01-modul-01-arhitectura-python/08-capitol-06-persistenta-si-adaptoare.md) | pachet complet + CG2-C06 | not started |
| M1-C07-001 | author/local | M1-C06-001 + CG2-C06 | [Capitolul 7](01-modul-01-arhitectura-python/09-capitol-07-testarea-arhitecturii.md) | pachet complet + CG2-C07 | not started |
| M1-C08-001 | author/local | M1-C07-001 + CG2-C07 | [Capitolul 8](01-modul-01-arhitectura-python/10-capitol-08-evolutie-si-adr.md) | pachet complet + CG2-C08 | not started |
| M1-CAPSTONE-001 | author/local | toate capitolele/gate-urile | [proiect integrator](01-modul-01-arhitectura-python/11-proiect-integrator.md) — numai artefacte capstone | proiect cumulativ + rubrică | not started |
| M1-INTEGRATE-001 | author/local | M1-CAPSTONE-001 | [integrare](02-quality/00-trasabilitate-si-review.md) — fișiere transversale și corecții listate/re-gated | manifest + raport coerență + teste cumulative WASM | not started |
| M1-TRACE-001 | review | M1-INTEGRATE-001 | [trasabilitate](02-quality/00-trasabilitate-si-review.md) | matrice fără orfani | not started |
| M1-TECH-QA-001 | review/local | M1-TRACE-001 | [review tehnic](02-quality/00-trasabilitate-si-review.md) | raport independent tehnic + matrice WASM | not started |
| M1-LANG-QA-001 | review | M1-TRACE-001 | [review lingvistic](02-quality/00-trasabilitate-si-review.md) | raport independent română | not started |
| M1-ASSESS-QA-001 | review | M1-TRACE-001 | [review evaluări](02-quality/00-trasabilitate-si-review.md) | raport independent itemi/chei/teste private WASM | not started |
| M1-FIX-001 | author/local | trei rapoarte QA pe aceeași revizie, dacă există finding | [remediere](02-quality/00-trasabilitate-si-review.md) — numai manifestul fix-NNN și fișierele enumerate în el | finding → diff + gate-uri revalidate | not started |
| M1-PUBLISH-001 | local | QA curate pe aceeași revizie + M1-FIX complete/N/A + Coditza G5 + G-WASM | [publicare locală](02-quality/01-verificare-tehnica-si-publicare.md) | generare + submit server-side WASM + traversal local fără leak | not started |

## Regula de sincronizare

După un task verificat:

1. atașează raportul;
2. marchează numai acel rând `complete`;
3. alege primul task cu toate prerechizitele complete drept `next`;
4. actualizează `STATUS.md` și `NEXT.md`;
5. dovedește unicitatea statusului activ și ordinea roadmapului.
