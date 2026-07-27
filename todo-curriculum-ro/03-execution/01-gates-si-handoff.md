# Gate-uri și handoff

## CG0 — Plan acceptat

- CURR-PLAN-001 este acceptat;
- CURR-PLAN-002 autorizează explicit redactarea;
- există exact un task `next`;
- standardele propuse nu contrazic limitările Coditza.

## CG1 — Fundație curriculară stabilă

- publicul/prerechizitele sunt aprobate;
- toolchain-ul și versiunea Python sunt fixate;
- G-WASM este trecut, iar versiunea Pyodide/CPython, asseturile self-hosted,
  allowlistul, limitele și hash-urile profilului sunt fixate;
- politica cheilor este sigură;
- schemele, validatoarele și fixture-urile contractului trec;
- schema multi-fișier `python_code`, testele publice/private și separarea lor
  trec fixture-urile pozitive/negative;
- aceeași trimitere are rezultat public canonic identic în verificatorul local
  și server-side WASM; contractul preview-ului browser viitor este documentat,
  fără a presupune un frontend;
- harta modulului și Study Tracker sunt stabile;
- `c00_tangled_script` rulează, este reconstruibil din Markdown și este etichetat
  drept anti-exemplu;
- glosarul nu are termeni ambigui;
- matricea inițială nu are obiective orfane.

## CG2-Cxx — Capitol complet

- contractul capitolului este complet;
- checkpointul/starterul/soluția au rezultatele de test documentate;
- pachetul `python_code` are versiune, `runtimeProfileRef`, digest, căi și limite
  valide;
- teoria, laboratorul, exercițiile și quizul acoperă obiectivele;
- starterul produce exact eșecurile publice declarate, iar soluția trece de două
  ori testele publice și private în WASM;
- codul și snippet-urile sunt verificate în WASM; CPython nativ nu este dovadă
  de gate;
- nu există scurgeri de răspunsuri;
- testele private/soluțiile nu apar în bundle-ul learner, iar runnerul nu
  primește secrete ori materiale Auth/TOTP;
- numai verificatorul server-side poate finaliza requestul `completed`, crea
  attemptul și acorda progres pentru `passed`; un rezultat browser viitor este
  numai provizoriu;
- review-urile tehnic și lingvistic ale capitolului sunt curate și indică aceeași
  revizie de ieșire;
- raportul enumeră comenzile și exit code-urile.

## CG3 — Modul integrat

- toate checkpointurile formează o aplicație cumulativă;
- toate checkpointurile și proiectul integrator trec în același profil WASM;
- termenii și arhitectura sunt consecvenți;
- proiectul integrator rulează;
- trasabilitatea este completă;
- niciun artefact nu este orfan.
- orice CG2 invalidat de integrare a fost rerulat pe revizia curentă.

## CG4 — Pachet local pregătit

- cele trei review-uri independente sunt curate, indică exact aceeași revizie
  finală și același hash al manifestului;
- M1-FIX-001 este `complete` pentru ultima iterație sau `not applicable`;
- generarea este deterministă;
- profilul/digesturile WASM corespund rapoartelor QA;
- resetul și încărcarea locală reușesc;
- submitul `python_code` valid/invalid este verificat autoritativ server-side,
  iar erorile de infrastructură nu sunt notate ca răspuns greșit;
- learner-ul parcurge modulul fără chei/soluții;
- manifestul și raportul sunt complete;
- nu a avut loc nicio mutație hosted.

## Raport de handoff

Fiecare task predă:

- ID și scope;
- revizia de intrare/ieșire;
- fișiere create/modificate;
- decizii folosite;
- comenzi și exit code;
- `runtimeProfileRef`, hash-ul profilului, digesturile pachetelor și rezultatele
  canonice ale rulărilor WASM;
- verificări trecute/eșuate;
- probleme și severitate;
- artefacte protejate atinse, fără conținutul lor;
- următorul task eligibil.

Un model nou citește README, control, registry, status, next, raportul ultimului
task și fișierul taskului următor înainte de orice modificare.
