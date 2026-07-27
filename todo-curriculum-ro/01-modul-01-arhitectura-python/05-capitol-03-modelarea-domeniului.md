# Capitolul 3 — Modelarea domeniului

## Obiective

- `M1-C03-O1`: separă regulile de domeniu de I/O și prezentare.
- `M1-C03-O2`: alege între entitate, obiect-valoare și funcție/serviciu de domeniu.
- `M1-C03-O3`: exprimă invariante prin constructori/metode și erori explicite.
- `M1-C03-O4`: scrie și testează reguli pure, deterministe.

## Secțiuni teoretice planificate

1. Ce înseamnă „domeniu” în Study Tracker.
2. Identitate, `dataclass` și obiecte-valoare.
3. Invariante și stări valide.
4. Funcții pure, timp/ID injectat și erori de domeniu.
5. Model anemic versus logică plasată intenționat.

## Laborator Study Tracker

Modelează activitatea de studiu, durata și regulile de finalizare. Elimină
citirea/scrierea din nucleul de domeniu și testează toate tranzițiile valide și
invalide fără filesystem. Testele publice/private folosesc ceas și UUID-uri
injectate și rulează în instanțe WASM curate.

## Evaluări planificate

- alegerea locului corect pentru o invariantă;
- diferențiere entitate/obiect-valoare;
- identificarea unei reguli contaminate de I/O;
- quiz cu tranziții de stare și fragmente `dataclass`.

## M1-C03-001 — Crearea pachetului Capitolului 3

Prerechizite: M1-C02-001 și CG2-C02.

- [ ] Creează checkpointul `c03_domain_model`.
- [ ] Păstrează domeniul fără importuri din adaptoare, CLI, SQLite sau config.
- [ ] Folosește timp și ID-uri controlate în teste.
- [ ] Prezintă cel puțin o alternativă rezonabilă și compromisul ei.
- [ ] Creează evaluările pentru `M1-C03-O1…O4`.
- [ ] Dovedește prin teste fiecare invariantă documentată.
- [ ] Dovedește în WASM că două rulări ale acelorași tranziții au același
      verdict și rezumat canonic.
