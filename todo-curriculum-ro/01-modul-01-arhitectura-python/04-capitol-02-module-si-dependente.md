# Capitolul 2 — Module, pachete și direcția dependențelor

## Obiective

- `M1-C02-O1`: grupează codul după responsabilitate și coeziune.
- `M1-C02-O2`: definește API-ul public al unui pachet și ascunde detaliile.
- `M1-C02-O3`: trasează și corectează direcția importurilor.
- `M1-C02-O4`: explică monolitul modular și importurile circulare.

## Secțiuni teoretice planificate

1. Modul, pachet și API public în Python.
2. Coeziune ridicată și motive de schimbare.
3. Graf de dependențe și importuri circulare.
4. Limite într-un monolit modular.
5. Refactorizare incrementală protejată de teste.

## Laborator Study Tracker

Separă scriptul în pachetele inițiale `domain`, `application` și `interfaces`,
fără schimbarea comportamentului. Adaugă un test care eșuează dacă `domain`
importă din interfața CLI. Verificarea importurilor analizează sursa/AST în
runtime-ul WASM și nu pornește procese ale hostului.

## Evaluări planificate

- clasificarea responsabilității corecte pentru funcții/clase;
- selectarea importurilor care încalcă direcția stabilită;
- diagnosticarea unui ciclu de import;
- quiz cu fragmente Python scurte și grafuri textuale de dependențe.

## M1-C02-001 — Crearea pachetului Capitolului 2

Prerechizite: M1-C01-001 și CG2-C01.

- [ ] Creează checkpointul `c02_packages` cu comportament păstrat.
- [ ] Arată un import circular real, izolat, apoi corecția testată.
- [ ] Explică de ce mutarea tuturor importurilor într-un fișier comun nu este o
      soluție arhitecturală.
- [ ] Creează exercițiile și quizul mapate la `M1-C02-O1…O4`.
- [ ] Verifică importurile printr-un test de arhitectură, nu doar manual.
- [ ] Împachetează modulele ca `python_code` multi-fișier și rulează testele
      publice/private în WASM, fără `subprocess` sau acces host.
- [ ] Rulează toate review-urile capitolului.
