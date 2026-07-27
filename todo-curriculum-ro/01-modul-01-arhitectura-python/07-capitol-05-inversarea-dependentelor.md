# Capitolul 5 — Inversarea și injectarea dependențelor

## Obiective

- `M1-C05-O1`: explică diferența dintre dependency inversion și injection.
- `M1-C05-O2`: definește un port minim cu `typing.Protocol`.
- `M1-C05-O3`: injectează un adaptor fără service locator sau framework DI.
- `M1-C05-O4`: construiește o rădăcină de compoziție explicită.

## Secțiuni teoretice planificate

1. Politică stabilă și detaliu volatil.
2. Dependency inversion versus dependency injection.
3. Porturi Python cu `Protocol` și contracte mici.
4. Adaptor în memorie și fake testabil.
5. Composition root și de ce dependențele nu se caută global.
6. Legătura cu arhitectura hexagonală.

## Laborator Study Tracker

Definește portul repository cerut de cazurile de utilizare, creează adaptorul în
memorie și compune aplicația într-un singur loc. Testele cazurilor de utilizare
injectează fake-ul. Pachetul multi-fișier și testele de contract sunt executate
în același profil WASM ca checkpointurile anterioare.

## Evaluări planificate

- identificarea dependenței orientate greșit;
- alegerea unui `Protocol` minim;
- compararea injectării prin constructor cu service locator;
- quiz care cere urmărirea direcției dependențelor.

## M1-C05-001 — Crearea pachetului Capitolului 5

Prerechizite: M1-C04-001 și CG2-C04.

- [ ] Creează checkpointul `c05_ports_and_memory`.
- [ ] Introdu numai porturi consumate efectiv; fără interfețe speculative.
- [ ] Interzice container DI/framework și mutable global registry.
- [ ] Arată explicit cine creează și conectează obiectele.
- [ ] Rulează typecheck și testele fake-ului.
- [ ] Rulează soluția cu testele publice/private în WASM; typecheckul nativ este
      suplimentar și nu înlocuiește verdictul.
- [ ] Creează evaluările pentru `M1-C05-O1…O4`.
