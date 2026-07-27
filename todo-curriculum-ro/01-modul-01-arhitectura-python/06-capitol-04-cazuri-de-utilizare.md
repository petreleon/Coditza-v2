# Capitolul 4 — Cazuri de utilizare și contracte

## Obiective

- `M1-C04-O1`: descrie operații prin intenția utilizatorului.
- `M1-C04-O2`: separă orchestrarea de regulile domeniului și prezentare.
- `M1-C04-O3`: definește DTO-uri, rezultate și erori așteptate.
- `M1-C04-O4`: identifică o limită tranzacțională.

## Secțiuni teoretice planificate

1. Straturile presentation/application/domain/infrastructure.
2. Caz de utilizare versus helper generic.
3. Comenzi, DTO-uri și rezultate stabile.
4. Erori de domeniu, aplicație și infrastructură.
5. Tranzacția ca limită a unui caz de utilizare.

## Laborator Study Tracker

Implementează cazurile `create_study_task`, `complete_study_task` și
`list_study_tasks`. CLI-ul transformă input-ul în DTO și formatează rezultatul;
nu conține reguli. Testele apelează entrypointul cu input/`sys.argv` controlat
în WASM; nu pornesc un proces al hostului.

## Evaluări planificate

- clasificarea logicii pe straturi;
- alegerea contractului pentru un caz de utilizare;
- recunoașterea unei erori tehnice scurse în interfață;
- quiz cu fluxuri complete request/input → use case → rezultat.

## M1-C04-001 — Crearea pachetului Capitolului 4

Prerechizite: M1-C03-001 și CG2-C03.

- [ ] Creează checkpointul `c04_use_cases`.
- [ ] Definește intrări/output-uri tipate și fără obiecte CLI/SQLite.
- [ ] Păstrează regulile în domeniu și orchestration-ul în application.
- [ ] Arată o limită tranzacțională fără a introduce încă baza reală de date.
- [ ] Creează evaluările pentru `M1-C04-O1…O4`.
- [ ] Verifică teste unitare separate pentru domeniu și cazuri de utilizare.
- [ ] Livrează checkpointul ca pachet `python_code` și trece testele publice și
      private în WASM fără `subprocess`, environment sau I/O nedeclarat.
