# Aplicația continuă Study Tracker

## Problemă

Aplicația gestionează activități de studiu. Utilizatorul poate:

- crea o activitate cu titlu și durată estimată;
- planifica activitatea pentru o dată;
- marca activitatea ca finalizată;
- lista activitățile;
- calcula minutele finalizate și progresul simplu.

## Invariante stabile

- titlul normalizat nu este gol;
- durata estimată este un număr întreg pozitiv;
- o activitate finalizată are o dată de finalizare;
- o activitate nu poate fi finalizată de două ori;
- progresul este derivat, nu introdus direct;
- regulile de domeniu nu citesc terminalul, fișierele, SQLite sau variabilele de
  mediu.

## Starea inițială intenționat slabă

Un script unic amestecă:

- parsing de argumente;
- validare;
- reguli;
- persistență JSON;
- formatarea output-ului;
- generarea timpului și ID-urilor.

Scriptul trebuie să fie mic, determinist și caracterizat prin teste înaintea
refactorizării. Anti-exemplul este etichetat ca material didactic, nu copiat ca
recomandare.

## Checkpointuri

```text
c00_tangled_script
c01_characterized
c02_packages
c03_domain_model
c04_use_cases
c05_ports_and_memory
c06_sqlite_adapter
c07_tested_architecture
c08_evolved_application
```

Fiecare checkpoint final:

- rulează independent;
- este împachetat ca trimitere multi-fișier `python_code` și trece verificarea
  server-side în profilul WASM fixat;
- include toate importurile și fișierele;
- nu conține `pass`, `...` sau pași ascunși;
- folosește `src/` layout și importuri absolute după C02;
- păstrează comportamentul relevant al checkpointului anterior;
- nu folosește rețea sau secrete;
- folosește numai modulele din allowlist; `sqlite3` apare numai de la C06 și
  numai pe filesystem-ul virtual;
- are comenzi și output așteptat documentate.

## Structura finală orientativă

```text
study_tracker/
├── pyproject.toml
├── src/study_tracker/
│   ├── domain/
│   ├── application/
│   ├── ports/
│   ├── adapters/
│   ├── interfaces/
│   └── bootstrap.py
└── tests/
    ├── unit/
    ├── contract/
    ├── integration/
    └── architecture/
```

Structura este rezultat al responsabilităților și dependențelor, nu obiectiv
decorativ.

Fiecare checkpoint are suplimentar `exercise.json`, starter/read-only,
`public-tests/`, teste private protejate și soluție de referință. Căile și
limitele respectă contractul WASM; testele nu pornesc procese și nu ating hostul.

## M1-EXAMPLE-001 — Specificarea proiectului de referință

Prerechizite: M1-OUTLINE-001.

- [ ] Fixează cerințele și invariantele de mai sus.
- [ ] Definește intrările/output-urile observabile ale scriptului inițial.
- [ ] Definește scopul exact al fiecărui checkpoint.
- [ ] Definește ce comportament trebuie păstrat și ce design se schimbă.
- [ ] Definește testele cumulative și testele specifice checkpointului.
- [ ] Pentru fiecare checkpoint, separă testele publice de cele private și
      definește starea așteptată a starterului și soluției în WASM.
- [ ] Injectează ceas/ID-uri și folosește directoare temporare.
- [ ] Interzice framework-uri DI, service locator și mutable globals.
- [ ] Mapează fiecare import la allowlist; niciun pachet third-party learner nu
      este permis în Modulul 1.

Dovada este o specificație verificabilă; implementarea codului începe în
taskul de baseline, nu aici.

## M1-BASELINE-001 — Crearea baseline-ului executabil C00

Prerechizite: M1-EXAMPLE-001 și CURR-WASM-001.

- [ ] Creează anti-exemplul complet în
      `examples/c00_tangled_script/starter/`; acesta este starterul primit de
      cursant pentru prima refactorizare.
- [ ] Creează testele smoke publice în
      `examples/c00_tangled_script/public-tests/` și oracle-ul/fixture-urile
      autorului în `protected-author/solutions/c00_tangled_script/`.
- [ ] Implementează exact intrările, output-urile și invariantele aprobate de
      M1-EXAMPLE-001, fără funcționalități suplimentare.
- [ ] Păstrează intenționat amestecul de CLI, reguli, JSON, timp și ID-uri, dar
      etichetează-l clar drept anti-exemplu didactic.
- [ ] Controlează timpul, ID-urile și directorul de date; nu folosește rețea,
      credentiale, mutable globals sau dependențe nedeclarate.
- [ ] Rulează CLI-ul prin entrypoint și `sys.argv` controlat în sandbox; nu
      folosește `subprocess` sau proces host.
- [ ] Include toate fișierele și importurile; interzice `pass`, `...` și pașii
      manuali ascunși.
- [ ] Rulează compilarea, format/lint, comanda smoke și testele publice de două
      ori în profilul WASM curat; rezultatele canonice sunt identice.
- [ ] Rulează soluția de referință cu testele publice și private prin
      verificatorul server-side WASM și înregistrează profilul/digestul.
- [ ] Nu refactorizează arhitectura și nu scrie încă testele de caracterizare;
      acestea aparțin M1-C01-001.
- [ ] Generează documentul learner complet și reconstruiește starterul într-un
      director gol pentru o a doua rulare.

Dovada este `c00_tangled_script` executabil și determinist în WASM, cu manifest
de fișiere, digesturi, comenzi, exit code-uri și output-uri așteptate, fără teste
private ori soluții în pachetul learner.
