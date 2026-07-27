# Roadmap curricular ordonat

Niciun task nu poate sări prerechizite sau gate-uri. Statusul autoritativ este
în [TASKS.md](../TASKS.md).

## CURR-PLAN-001 — Acceptarea planului curricular

- [ ] Utilizatorul acceptă sau modifică publicul, capitolele și aplicația.
- [ ] Utilizatorul acceptă sau modifică politica quizurilor.
- [ ] Înregistrează cerința deja explicită: `python_code` este verificat
      autoritativ server-side în Python-on-WebAssembly; CPython nativ și
      preview-ul browser viitor nu acordă progres.
- [ ] Orice modificare este sincronizată în toate fișierele afectate.

Acest task nu autorizează redactarea.

## CURR-PLAN-002 — Autorizarea redactării

- [ ] Utilizatorul cere explicit crearea conținutului și exemplelor Python.
- [ ] Se confirmă scope-ul primei faze și fișierele permise.
- [ ] `STATUS.md` înregistrează autorizarea.

## Faza 1 — Standarde și fundație

1. [ ] CURR-STD-001 — standarde editoriale, toolchain și protecția cheilor.
2. [ ] Așteaptă G-WASM din planul tehnic Coditza; fără profilul lock-uit și
   verificatorul server-side, CURR-WASM-001 rămâne `blocked`.
3. [ ] CURR-WASM-001 — contract multi-fișier, allowlist, fixture-uri,
   determinism, paritate server/local și contractul preview-ului viitor.
4. [ ] Așteaptă G5 din planul tehnic Coditza; fără OpenAPI-ul de authoring
   generat, CURR-FORMAT-001 rămâne `blocked`.
5. [ ] CURR-FORMAT-001 — scheme, șabloane, validatoare și separarea cheilor
   legate de OpenAPI-ul care a trecut G5.
6. [ ] M1-OUTLINE-001 — harta exactă a modulului.
7. [ ] M1-EXAMPLE-001 — specificația Study Tracker.
8. [ ] M1-BASELINE-001 — anti-exemplul C00 executabil și reconstruibil în WASM.
9. [ ] M1-GLOSSARY-001 — glosarul canonic.
10. [ ] Verifică CG1.

## Faza 2 — Capitole

În ordine strictă:

1. [ ] M1-C01-001 — nevoia de arhitectură; verifică CG2-C01.
2. [ ] M1-C02-001 — module și dependențe; verifică CG2-C02.
3. [ ] M1-C03-001 — modelarea domeniului; verifică CG2-C03.
4. [ ] M1-C04-001 — cazuri de utilizare; verifică CG2-C04.
5. [ ] M1-C05-001 — inversarea dependențelor; verifică CG2-C05.
6. [ ] M1-C06-001 — persistență și adaptoare; verifică CG2-C06.
7. [ ] M1-C07-001 — testarea arhitecturii; verifică CG2-C07.
8. [ ] M1-C08-001 — evoluție și ADR; verifică CG2-C08.

## Faza 3 — Integrare

1. [ ] M1-CAPSTONE-001 — proiectul integrator cumulativ.
2. [ ] M1-INTEGRATE-001 — coerență între capitole.
3. [ ] M1-TRACE-001 — matrice finală obiectiv–conținut–evaluare.
4. [ ] Verifică CG3.

## Faza 4 — Review și pachet local

Review-urile pot rula în paralel numai după M1-TRACE-001 și pe aceeași revizie:

1. [ ] M1-TECH-QA-001 — review tehnic independent.
2. [ ] M1-LANG-QA-001 — review lingvistic independent.
3. [ ] M1-ASSESS-QA-001 — review independent al evaluărilor.
4. [ ] Dacă toate trei sunt curate, marchează M1-FIX-001 `not applicable`.
5. [ ] Dacă există orice finding, rulează M1-FIX-001: declară fișierele,
   invalidează și rerulează gate-urile afectate, apoi repetă toate cele trei
   review-uri pe aceeași revizie nouă; repetă ciclul până sunt curate.
6. [ ] După ce planul tehnic Coditza dovedește G5 și G-WASM, M1-PUBLISH-001 —
   generează pachetul și verifică submitul server-side WASM numai local; până
   atunci taskul rămâne blocat.
7. [ ] Verifică CG4 pe aceeași revizie și același hash de manifest ca rapoartele.

Nu există în acest roadmap un task de publicare hosted/production.
