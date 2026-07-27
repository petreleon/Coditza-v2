# Capitolul 6 — Persistență și adaptoare

## Obiective

- `M1-C06-O1`: implementează un adaptor care respectă un port existent.
- `M1-C06-O2`: mapează explicit între rânduri și obiecte de domeniu.
- `M1-C06-O3`: gestionează tranzacții și erori tehnice la limită.
- `M1-C06-O4`: schimbă persistența fără schimbarea domeniului/cazurilor de utilizare.

## Secțiuni teoretice planificate

1. Adaptoare de intrare și ieșire.
2. Repository în memorie versus SQLite.
3. Mapping explicit și evitarea modelului de domeniu dependent de ORM.
4. Tranzacții, commit/rollback și erori tehnice.
5. Configurare la composition root.
6. MVC comparat cu porturi/adaptoare pentru o viitoare interfață web.

## Laborator Study Tracker

Adaugă un adaptor SQLite folosind o bază temporară. Rulează aceeași aplicație cu
adaptorul în memorie și SQLite prin schimbarea composition root-ului, nu a
regulilor. Baza există numai în filesystem-ul virtual nou al rulării WASM.

## Evaluări planificate

- selectarea locului mapping-ului;
- detectarea unei dependențe de SQLite în domeniu;
- alegerea limitei de tranzacție;
- quiz cu două implementări ale aceluiași port.

## M1-C06-001 — Crearea pachetului Capitolului 6

Prerechizite: M1-C05-001 și CG2-C05.

- [ ] Creează checkpointul `c06_sqlite_adapter`.
- [ ] Verifică înainte fixture-ul de conformitate `sqlite3` al profilului WASM;
      dacă nu trece, blochează taskul și nu folosește CPython nativ ca fallback.
- [ ] Folosește numai SQLite temporar și determinist; fără rețea.
- [ ] Păstrează schema/mapping-ul în adaptor.
- [ ] Dovedește rollback-ul la o eroare simulată.
- [ ] Dovedește că domeniul/application nu importă SQLite.
- [ ] Creează evaluările pentru `M1-C06-O1…O4`.
- [ ] Rulează rollback-ul și aceeași suită de contract de două ori în instanțe
      WASM curate.
