# Capitolul 7 — Testarea arhitecturii

## Obiective

- `M1-C07-O1`: alege nivelul de test potrivit pentru un risc.
- `M1-C07-O2`: diferențiază fake, mock, test de contract și integrare.
- `M1-C07-O3`: rulează același contract pentru două adaptoare.
- `M1-C07-O4`: automatizează reguli de import și limite arhitecturale.

## Secțiuni teoretice planificate

1. Riscuri și piramida testelor.
2. Teste unitare pentru domeniu și cazuri de utilizare.
3. Fake versus mock și fragilitatea verificării implementării.
4. Teste de contract pentru adaptoare substituibile.
5. Teste de integrare pentru SQLite.
6. Teste de arhitectură pentru importuri și dependențe.

## Laborator Study Tracker

Definește o suită comună de contract și ruleaz-o pentru repository-ul în memorie
și SQLite. Adaugă verificări fără să folosești săgeți ambigue: `domain` nu poate
importa `application`, `interfaces`, `adapters`, `infrastructure` sau SQLite;
`application` poate importa `domain` și porturi, dar nu adaptoare concrete,
`infrastructure` sau SQLite. Adaptoarele/infrastructura pot depinde spre interior
de tipurile domeniului și de porturile aplicației. Păstrează testele de
caracterizare încă utile. Toate suitele folosesc mecanisme disponibile în
profilul WASM; verificarea importurilor analizează sursa/AST, nu procese host.

## Evaluări planificate

- asocierea riscului cu nivelul de test;
- alegerea fake/mock potrivit;
- identificarea unui test cuplat la implementare;
- quiz cu o matrice risc–test și rezultate de suite.

## M1-C07-001 — Crearea pachetului Capitolului 7

Prerechizite: M1-C06-001 și CG2-C06.

- [ ] Creează checkpointul `c07_tested_architecture`.
- [ ] Rulează contractul identic pentru ambele adaptoare.
- [ ] Include cel puțin un test de integrare cu rollback/izolare.
- [ ] Include teste automate pentru regulile explicite de import de mai sus.
- [ ] Rulează testele unitare, de contract, integrare și arhitectură, publice și
      private, în profilul WASM; nicio trecere numai nativă nu este acceptată.
- [ ] Explică ce nu poate dovedi fiecare nivel de test.
- [ ] Creează evaluările pentru `M1-C07-O1…O4`.
