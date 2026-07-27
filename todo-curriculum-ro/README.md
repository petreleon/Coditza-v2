# Plan curricular Coditza în limba română

## Scop

Acest director este al doilea plan al proiectului Coditza. El descrie exclusiv
crearea conținutului educațional în limba română. Planul tehnic al aplicației
rămâne separat în `../todo/`.

Primul modul real de curs este:

> **Modulul 1 — Arhitectură software în Python**

Modulul folosește o singură aplicație de referință, **Study Tracker**, care este
refactorizată incremental. Cursantul învață să recunoască responsabilități,
limite și compromisuri, apoi aplică modularizarea, modelarea domeniului,
arhitectura stratificată, inversarea dependențelor, porturile și adaptoarele,
persistența și testarea arhitecturii.

## Restricția actuală

Acum se creează numai planul:

- nu se redactează încă lecțiile finale;
- nu se creează codul Python al cursului;
- nu se creează payload-uri sau date în Supabase;
- nu se deschide Chrome;
- nu se publică nimic în Coditza;
- toate căsuțele rămân nebifate.

## Cum va folosi un model mai slab acest plan

1. Citește toate fișierele din `00-control/`.
2. Citește [TASKS.md](TASKS.md), [STATUS.md](STATUS.md) și [NEXT.md](NEXT.md).
3. Execută exact un singur task cu statusul `next`.
4. Citește fișierul capitolului și toate prerechizitele lui.
5. Creează numai artefactele permise de acel task.
6. Rulează verificările tehnice, lingvistice și de evaluare cerute.
7. Pentru orice cod Python, folosește profilul WebAssembly cerut de
   [contractul WASM](00-control/05-contract-verificare-python-wasm.md); o
   rulare CPython nativă nu este dovadă de acceptare.
8. Nu marchează un task ca finalizat doar pentru că există fișierele.
9. Actualizează împreună registrul, statusul și următorul task.
10. Se oprește la fiecare gate și la fiecare decizie nerezolvată.

## Index

| Categorie | Conținut |
| --- | --- |
| [Control](00-control/00-scop-si-decizii.md) | scop, public, limbă, contracte și [verificarea Python WASM](00-control/05-contract-verificare-python-wasm.md) |
| [Modulul 1](01-modul-01-arhitectura-python/00-harta-modulului.md) | harta și planurile celor opt capitole |
| [Calitate](02-quality/00-trasabilitate-si-review.md) | trasabilitate, review tehnic, lingvistic și evaluări |
| [Execuție](03-execution/00-roadmap.md) | ordine, gate-uri și handoff |
| [Șabloane](04-templates/00-sabloane-continut.md) | structura exactă a artefactelor viitoare |

## Rezultatul final planificat

După implementarea ulterioară a acestui plan, Coditza va avea un modul publicat
cu opt capitole ordonate. Fiecare capitol va avea secțiuni teoretice, cel puțin
trei exerciții compatibile cu tipurile Coditza și un quiz. Fiecare laborator
Python va avea un pachet multi-fișier `python_code`, teste publice și teste
private. Acceptarea va fi decisă exclusiv de verificatorul server-side în
profilul Python-on-WebAssembly fixat. Un preview viitor din browser va rula
numai testele publice și va rămâne provizoriu; acest plan nu implementează un
frontend.
