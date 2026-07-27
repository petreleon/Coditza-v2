# Protocol de execuție și definiția finalizării

## Regula unui singur task

- Un singur rând poate avea statusul `next` sau `in progress`.
- Taskul modifică numai artefactele pe care le deține.
- Prerechizitele și gate-ul anterior trebuie să fie complete.
- Un reviewer produce raport; nu repară materialul în același task.
- O corecție primește o iterație numerotată și un manifest explicit al
  finding-urilor, fișierelor și gate-urilor afectate.
- `TASKS.md`, `STATUS.md` și `NEXT.md` se actualizează în aceeași schimbare.

## Statusul `needs revalidation`

- Înseamnă că artefactul a fost aprobat anterior, dar dovada sa nu mai este
  valabilă pentru revizia curentă.
- Se aplică înainte de prima editare care atinge artefactul; nu după editare.
- Un rând cu acest status nu satisface niciun prerechizit și nu permite
  publicarea.
- Revine la `complete` numai după rerularea gate-ului pe noua revizie.
- Dacă o nouă rundă de review găsește probleme, M1-FIX-001 se redeschide ca
  `next`; nu se inventează ID-uri wildcard precum `FIX-*`.

## Review-ul intern al unui capitol

- M1-Cxx-001 rămâne singurul task de editare și `in progress` până la gate.
- Un reviewer tehnic și unul lingvistic, diferiți de autor, atașează rapoarte
  numerotate fără să editeze.
- Autorul corectează finding-urile în același task de capitol, apoi reviewerii
  rerulează verificările.
- CG2-Cxx acceptă numai rapoarte curate care indică aceeași revizie de ieșire.
- După CG2-Cxx, orice corecție transversală folosește manifestul controlat de
  M1-INTEGRATE-001 sau M1-FIX-001 și redeschide gate-ul.

## Ordinea internă a unui task de capitol

1. citește obiectivele și glosarul;
2. fixează `runtimeProfileRef` și versiunea definiției `python_code`;
3. scrie testele publice și private/criteriile checkpointului;
4. creează sau refactorizează codul checkpointului;
5. generează manifestul multi-fișier și hash-urile pachetului;
6. rulează starterul și soluția de două ori în profilul WASM;
7. extrage blocurile de cod din sursa testată;
8. redactează teoria;
9. redactează exercițiile;
10. redactează quizul și separat cheile;
11. completează matricea obiectiv–teorie–exercițiu–quiz;
12. rulează toate verificările;
13. cere review tehnic și lingvistic independent.

## Comenzi viitoare obligatorii

Comenzile exacte sunt stabilite de CURR-STD-001, dar trebuie să acopere:

- validarea JSON Schema și a referințelor;
- Markdown, linkuri și raw HTML;
- Unicode NFC, diacritice și terminologie;
- drift între snippet și sursa Python;
- compilare, format/lint și typecheck strict ca verificări de authoring;
- validarea profilului/digestului, căilor, allowlistului și limitelor
  `python_code`;
- teste publice și private unitare, de contract, integrare și arhitectură în
  runtime-ul WASM fixat;
- două rulări WASM cu rezultat canonic identic și paritate server/local pentru
  testele publice;
- scanarea bundle-ului learner pentru teste private, soluții, secrete și
  materiale Auth/TOTP;
- structură/ambiguitate/coverage pentru evaluări;
- generare deterministă, cu a doua rulare fără diff;
- încărcare locală și parcurgere prin API fără scurgerea cheilor.

## Definiția finalizării unui capitol

Un capitol este complet numai dacă:

- toate obiectivele sunt predate, exersate și evaluate;
- toate exemplele și soluțiile rulează în mediul fixat;
- fiecare exercițiu/laborator Python are pachet multi-fișier versionat,
  `runtimeProfileRef` și digest;
- direcția importurilor respectă arhitectura predată;
- starterul și soluția au stările de test documentate;
- starterul are exact eșecurile publice declarate, iar soluția trece testele
  publice și private de două ori în profilul WASM;
- verificarea server-side emite verdictul autoritativ; CPython nativ și un
  viitor rezultat browser provizoriu nu satisfac gate-ul;
- nu există chei/soluții în artefactele cursantului;
- nu există teste private, tokenuri, credențiale sau materiale TOTP în bundle-ul
  learner ori în runner;
- quizul nu are itemi ambigui sau opinion-based;
- limba română și termenii sunt consecvenți;
- review-ul tehnic și cel lingvistic sunt curate pe aceeași revizie de ieșire;
- raportul include comenzile, codurile de ieșire și artefactele verificate.

## Definiția finalizării modulului

- opt capitole complete și ordonate;
- aplicația Study Tracker funcționează cumulativ;
- toate checkpointurile și capstone-ul trec în același profil WASM publicat;
- fiecare obiectiv global are trasabilitate;
- proiectul integrator are teste și rubrică de autoevaluare;
- comparația arhitecturilor prezintă compromisuri, nu verdicte absolute;
- toate review-urile finale sunt aprobate de persoane/agenți diferiți de autor
  și atestă aceeași revizie finală și același hash al manifestului;
- pachetul este verificat local în Coditza prin fluxul server-side WASM înaintea
  oricărei publicări;
- publicarea în producție rămâne o acțiune separată și autorizată.
