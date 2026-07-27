# Capitolul 8 — Evoluție și decizii arhitecturale

## Obiective

- `M1-C08-O1`: evaluează o schimbare folosind atribute de calitate și cost.
- `M1-C08-O2`: scrie un ADR cu context, opțiuni, decizie și consecințe.
- `M1-C08-O3`: compară monolit modular, MVC, evenimente și microservicii.
- `M1-C08-O4`: recunoaște momentul când complexitatea nu este justificată.

## Secțiuni teoretice planificate

1. Arhitectura evoluează sub presiunea schimbărilor.
2. Refactorizare incrementală și compatibilitate.
3. ADR: context, forțe, opțiuni, decizie, consecințe.
4. Interfețe CLI/web și MVC ca separare.
5. Evenimente: decuplare, consistență și cost operațional.
6. Microservicii: limite organizaționale, date și distribuție.
7. Observabilitate, config și erori la limite.

## Laborator Study Tracker

Adaugă o nouă interfață de raportare fără a schimba domeniul/persistența. Scrie
două ADR-uri: alegerea monolitului modular cu porturi/adaptoare și alegerea
SQLite. Evaluează, fără a implementa, o variantă bazată pe evenimente. Interfața
nouă este apelată în sandboxul WASM și nu pornește server, browser ori proces.

## Evaluări planificate

- alegerea unei soluții proporționale într-un scenariu;
- completarea consecințelor unui ADR;
- identificarea costurilor distribuției;
- quiz bazat pe scenarii, fără întrebarea „care este cea mai bună arhitectură?”.

## M1-C08-001 — Crearea pachetului Capitolului 8

Prerechizite: M1-C07-001 și CG2-C07.

- [ ] Creează checkpointul `c08_evolved_application`.
- [ ] Adaugă interfața nouă exclusiv prin limitele existente sau justifică o
      schimbare de contract.
- [ ] Scrie ADR-urile cu alternative respinse și consecințe negative.
- [ ] Păstrează ADR-urile ca artefacte learner separate; requestul
      `python_code` conține numai fișiere `.py`.
- [ ] Compară stilurile pe aceeași matrice de criterii.
- [ ] Nu transformă microserviciile într-un premiu pentru maturitate.
- [ ] Creează evaluările pentru `M1-C08-O1…O4`.
- [ ] Rulează checkpointul multi-fișier, inclusiv `sqlite3`, de două ori în WASM
      și păstrează același profil/digest ca restul modulului.
