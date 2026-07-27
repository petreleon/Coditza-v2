# Capitolul 1 — De ce avem nevoie de arhitectură

## Obiective

- `M1-C01-O1`: distinge arhitectura de simpla organizare a fișierelor.
- `M1-C01-O2`: clasifică cerințe funcționale și atribute de calitate.
- `M1-C01-O3`: identifică responsabilități, cuplare, coeziune și efectele lor.
- `M1-C01-O4`: explică de ce o alegere arhitecturală este un compromis.

## Secțiuni teoretice planificate

1. De la script care funcționează la sistem care se schimbă.
2. Cerințe funcționale și atribute de calitate.
3. Responsabilități, limite, cuplare și coeziune.
4. Arhitectura nu este o diagramă sau un arbore de directoare.
5. Tur comparativ: stratificată, modulară, hexagonală, MVC și microservicii.

## Laborator Study Tracker

Rulează scriptul inițial, identifică comportamentele observabile și adaugă teste
de caracterizare fără a refactoriza. Marchează locurile unde I/O-ul, regulile și
formatarea sunt cuplate. Checkpointul este un pachet multi-fișier `python_code`;
testele de caracterizare publice și private rulează în profilul WASM.

## Evaluări planificate

- exercițiu `single_choice`: cerință funcțională vs. atribut de calitate;
- exercițiu `multiple_choice`: simptome ale responsabilităților amestecate;
- exercițiu de analiză: limita inițială potrivită într-un fragment de script;
- quiz de minimum opt itemi, cu acoperire pentru toate cele patru obiective.

## M1-C01-001 — Crearea pachetului Capitolului 1

Prerechizite: M1-GLOSSARY-001, M1-BASELINE-001 și CG1.

- [ ] Creează testele de caracterizare și checkpointul `c01_characterized`.
- [ ] Declară rezultatul public al starterului și dovedește de două ori în WASM
      că soluția păstrează comportamentul caracterizat.
- [ ] Redactează toate secțiunile conform contractului.
- [ ] Include un exemplu în care multe fișiere au în continuare cuplare mare.
- [ ] Creează cele trei exerciții și quizul fără întrebări de opinie.
- [ ] Completează coverage pentru `M1-C01-O1…O4`.
- [ ] Rulează verificările tehnice, lingvistice și de evaluare.

Capitolul trece CG2-C01 numai dacă refactorizarea nu a început prematur, iar
cursantul poate explica problema înainte de soluție.
