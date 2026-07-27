# Harta Modulului 1

## Identitate

- Titlu: `Arhitectură software în Python`
- Slug: `arhitectura-software-python`
- Limbă: `ro-RO`
- Nivel: începător-avansat / intermediar timpuriu
- Durată țintă: 18–24 de ore, inclusiv laboratoare
- Format: opt capitole progresive și un proiect integrator
- Runtime de acceptare: profilul Python-on-WebAssembly fixat de CURR-WASM-001

Fiecare checkpoint are un pachet multi-fișier `python_code`. Profilul runtime
nu se schimbă între capitole fără invalidarea și revalidarea tuturor
checkpointurilor deja aprobate.

## Ordinea capitolelor

| Poziție | Capitol | Rezultat principal | Checkpoint Study Tracker |
| ---: | --- | --- | --- |
| 0 | De ce avem nevoie de arhitectură | identifică responsabilități și atribute de calitate | teste de caracterizare pentru script |
| 1 | Module, pachete și direcția dependențelor | creează limite și elimină importurile circulare | pachete `domain/application/interfaces` |
| 2 | Modelarea domeniului | izolează reguli și invariante fără I/O | modelul activității de studiu |
| 3 | Cazuri de utilizare și contracte | orchestrează intențiile utilizatorului | create/complete/list use cases |
| 4 | Inversarea dependențelor | definește porturi și composition root | repository `Protocol` + memorie |
| 5 | Persistență și adaptoare | schimbă detaliile fără a schimba politica | adaptor SQLite |
| 6 | Testarea arhitecturii | dovedește substituibilitatea și limitele | teste contract/integration/import |
| 7 | Evoluție și decizii arhitecturale | alege proporțional și scrie ADR-uri | interfață nouă + decizie documentată |

## Reguli de dependență între capitole

- C01 stabilește vocabularul; niciun capitol ulterior nu îl redefinește.
- C02 păstrează comportamentul prin teste de caracterizare.
- C03 nu importă CLI, SQLite sau framework.
- C04 depinde de domeniu, dar domeniul nu depinde de cazurile de utilizare.
- C05 introduce abstracții numai când există un consumator și două implementări
  planificate.
- C06 nu schimbă contractele domeniului pentru a se potrivi bazei de date.
- C06 pornește numai după ce fixture-ul `sqlite3` trece în profilul WASM; lipsa
  capabilității blochează capitolul, fără fallback nativ.
- C07 rulează aceeași suită de contract pentru adaptoarele memorie și SQLite.
- C08 compară alternativele după ce cursantul a construit o variantă coerentă.

## M1-OUTLINE-001 — Înghețarea hărții modulului

Prerechizite: CURR-FORMAT-001.

- [ ] Confirmă titlul, slug-ul, nivelul și durata.
- [ ] Confirmă exact opt capitole și ordinea din tabel.
- [ ] Atribuie fiecărei competențe globale unul sau mai multe capitole.
- [ ] Verifică faptul că fiecare capitol are prerechizite satisfăcute anterior.
- [ ] Definește checkpointul Study Tracker produs de fiecare capitol.
- [ ] Mapează fiecare checkpoint la pachetul său `python_code`, testele publice/
      private și același `runtimeProfileRef`.
- [ ] Confirmă că MVC, evenimentele și microserviciile sunt comparații, nu
      implementări distribuite obligatorii.
- [ ] Creează matricea inițială de trasabilitate fără a redacta conținut final.

Dovada este harta aprobată și matricea fără obiective orfane.
