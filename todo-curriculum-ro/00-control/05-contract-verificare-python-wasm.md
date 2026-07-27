# Contractul verificării Python prin WebAssembly

Acest fișier este autoritativ pentru orice laborator, checkpoint sau exercițiu
`python_code` din curriculum. Codul Python al cursantului este acceptat de
Coditza numai după verificare în runtime-ul Python-on-WebAssembly fixat de
proiect. O rulare cu Python nativ instalat pe calculator nu satisface niciun
gate curricular.

## Decizia de runtime

- Runtime-ul planificat este Pyodide: CPython compilat pentru WebAssembly.
- Implementatorul revalidează înainte de pinning
  [referințele tehnice oficiale](../../todo/00-control/05-official-references.md#python-on-webassembly);
  linkurile sunt surse de verificat, nu versiuni implicite.
- CURR-WASM-001 fixează versiunea exactă Pyodide, versiunea CPython raportată,
  hash-urile asseturilor, pachetele incluse și un `runtimeProfileRef` imuabil.
- Asseturile runtime și pachetele sunt self-hosted de Coditza; CDN-urile,
  `micropip`, instalarea la execuție și downloadurile dinamice sunt interzise.
- Viitorul runner din browser va rula runtime-ul într-un Web Worker de tip
  module, niciodată pe thread-ul principal.
- Verificatorul server-side și verificatorul local al autorului folosesc același
  profil blocat și aceleași hash-uri. Viitorul runner din browser trebuie să
  consume același profil când va exista.
- Un mismatch de profil, manifest sau hash oprește verificarea cu eroare de
  infrastructură; nu se face fallback silențios la Python nativ.

Python nativ poate fi folosit de autor ca ajutor rapid pentru formatter, lint,
typecheck sau debugging. Dovada de acceptare trebuie însă să includă rularea
suitei în profilul WASM fixat.

## Tipul `python_code`

`python_code` este permis pentru exerciții și laboratoare. El poate primi o
trimitere cu mai multe fișiere, necesară pentru module, pachete și limite
arhitecturale. Quizurile Modulului 1 rămân conceptuale și folosesc
`single_choice`, `multiple_choice` sau `short_text`; adăugarea codului executabil
în quiz cere o decizie curriculară separată.

Numele câmpurilor API rămân provizorii până când OpenAPI-ul backend-ului care a
trecut gate-ul tehnic definește contractul final. Generatorul curricular mapează
schema canonică de mai jos la acel OpenAPI; nu ghicește și nu trimite câmpuri
necunoscute.

## Pachetul canonic al unui exercițiu

Fiecare exercițiu executabil are exact această separare logică:

```text
python-exercises/<exercise-ref>/
├── exercise.json
├── starter/
├── readonly/
└── public-tests/
protected-author/
├── python-private-tests/<exercise-ref>/
└── solutions/<exercise-ref>/
```

`exercise.json`, starterul, fișierele read-only și testele publice pot ajunge la
cursant. Testele private, soluția de referință și oracolul rămân protejate și nu
sunt incluse în bundle-ul browserului, cache, source map, payload learner, log
sau raport public.

Manifestul learner `exercise.json` conține obligatoriu:

- `schemaVersion`, `exerciseRef`, `objectiveRefs` și `runtimeProfileRef`;
- instrucțiunile în română și fișierele starter;
- entrypoint-ul, politica pentru fișiere `.py` suplimentare și căile read-only
  rezervate;
- ID-urile stabile ale testelor publice;
- limite explicite pentru număr de fișiere, bytes, timp și output;
- pentru fiecare fișier livrat: cale, rol și SHA-256;
- starea așteptată a starterului: ce teste publice trec și ce teste eșuează;
- codurile de feedback sigur asociate fazelor de validare și testelor publice.

Manifestul protejat adaugă ID-urile testelor private, hash-urile lor, rezultatul
așteptat al soluției de referință și justificarea acoperirii. Nu copiază aceste
date în manifestul learner.

Fișierele din `python-private-tests/` sunt surse protejate de authoring, nu
payload runtime. Pipeline-ul curricular le validează și le compilează în planul
de cazuri declarativ, închis și versionat cerut de `SUP-WASM-001`. Baza de date,
jobul și sandbox-ul nu primesc sursă Python privată arbitrară; primesc numai
planul înghețat și fixture-urile strict necesare, toate identificate prin
digest.

## Reguli pentru fișiere și trimitere

- Căile trimise sunt relative POSIX, au 1–160 de caractere ASCII, folosesc
  numai litere, cifre, `_`, `-`, `.` și `/` și se termină în `.py`.
- Sunt respinse căile absolute, segmentele goale, `.`, `..`, `\`, NUL,
  symlinkurile, hard linkurile, device entries, arhivele și fișierele în afara
  rădăcinii virtuale.
- Sunt respinse căile duplicate și coliziunile după ASCII case-folding, chiar
  dacă filesystem-ul curent le-ar considera distincte.
- O trimitere conține 1–16 fișiere text UTF-8, maximum 65.536 bytes per fișier
  și maximum 262.144 bytes în total.
- Ordinea canonică este ordinea crescătoare a bytes-urilor căii; conținutul este
  păstrat exact și inclus în hash-ul canonic al requestului.
- Fixture-urile read-only `.json`, `.txt` sau `.csv` aparțin definiției
  publicate și sunt montate de server; clientul nu le retrimite.
- Lipsa entrypointului cerut, trimiterea unei căi rezervate/read-only sau un
  fișier care încalcă regulile produce o eroare de validare înaintea rulării;
  verificatorul nu repară trimiterea.
- La fiecare rulare se creează un filesystem virtual nou și se montează numai
  fișierele declarate. Nicio stare nu este reutilizată între două încercări.

CURR-WASM-001 copiază limitele autoritative de timp, memorie și output din
contractul tehnic într-un profil versionat. Până când aceste valori sunt fixate,
niciun pachet `python_code` nu poate trece CG1.

## Subset Python și pachete permise

Codul aplicației learner poate folosi builtins pure și numai modulele standard
din allowlistul profilului. Allowlistul inițial pentru Modulul 1 este:

```text
__future__, abc, argparse, ast, collections, contextlib, dataclasses, datetime,
enum, functools, io, itertools, json, math, operator, pathlib, re, sqlite3,
statistics, string, sys, tempfile, types, typing, unittest, uuid
```

Reguli suplimentare:

- `sqlite3` este activ numai pentru C06, C07, C08 și proiectul integrator, după
  ce fixture-ul de capabilitate WASM dovedește tranzacții, rollback și izolare;
- timpul, UUID-urile și orice entropie sunt injectate; `datetime.now()`,
  `uuid.uuid4()` și surse echivalente necontrolate sunt interzise în
  comportamentul verificat;
- `open()` și `pathlib` văd numai filesystem-ul virtual al rulării;
- testele pot folosi versiunea exactă `pytest` inclusă în profilul self-hosted;
  codul aplicației learner nu importă `pytest`;
- niciun alt pachet third-party nu este permis în Modulul 1. Adăugarea unuia
  cere allowlist, versiune exactă, hash, asset self-hosted, fixture de
  compatibilitate WASM și revalidarea tuturor pachetelor afectate.

Sunt interzise explicit în codul learner: `micropip`, `js`, bridge-ul
`pyodide`, `importlib`, `eval`, `exec`, `compile`, `__import__`, accesul la
environment, procese, threaduri, socketuri, HTTP, browser APIs și orice mecanism
de încărcare dinamică.
Lista de importuri interzise include cel puțin `subprocess`, `multiprocessing`,
`socket`, `ssl`, `urllib`, `http`, `ctypes` și `webbrowser`. Validatorul static
oferă feedback timpuriu, dar sandbox-ul runtime aplică limita independent.

## Determinismul testelor

Fiecare test public sau privat:

- are ID stabil, un singur comportament principal și timeout propriu;
- pornește dintr-un runtime și filesystem curate;
- nu folosește rețea, credențiale, ora reală, locale/timezone ale hostului,
  ordine nedeterministă, memorie persistentă sau concurență;
- injectează ceasul și ID-urile, fixează orice seed permis și sortează
  colecțiile înaintea comparațiilor de output;
- folosește numai fixture-uri incluse și declarate prin hash;
- normalizează output-ul la UTF-8 și LF înaintea comparației;
- produce același verdict și același rezumat canonic pentru aceeași combinație
  de digesturi runtime manifest + definiție + fixture + harness + trimitere.

Soluția de referință trebuie să treacă toate testele publice și private.
Starterul trebuie să aibă exact rezultatele publice declarate. Un test flaky sau
un rezultat diferit între două rulări consecutive blochează pachetul.
Testele publice sunt feedback pedagogic; trecerea lor nu dovedește și nu pretinde
trecerea testelor private.

## Browser viitor: rulare locală provizorie

Repository-ul curent nu are frontend, iar acest plan curricular nu creează unul
și nu alege un framework. Pachetul definește testele publice și contractul
necesar unei integrări viitoare într-un Web Worker de tip module.

- Browserul primește numai starterul/read-only, testele publice și runtime-ul
  self-hosted verificat prin hash.
- Web Worker-ul rulează validarea statică și testele publice; nu primește teste
  private, soluții, answer specs, tokenuri, coduri TOTP sau secrete.
- Rezultatul este etichetat exact `Rezultat local provizoriu`.
- Succesul local nu creează attempt verificat, scor, progres sau certificat și
  nu poate debloca următorul capitol.
- Dacă browserul este offline și asseturile/problema sunt deja cache-uite,
  testele publice pot rula provizoriu. Rezultatul local nu este sincronizat ca
  adevăr și nu produce auto-submit; când serverul revine, cursantul trimite
  explicit codul pentru verificare autoritativă.
- Dacă WebAssembly, Web Worker-ul sau profilul fixat nu sunt disponibile, UI-ul
  explică indisponibilitatea; nu declară succes și nu cade pe CPython nativ.
  Un client online poate oferi submit direct către server fără preview.

## Server: verificare autoritativă

Backend-ul validează tokenul Supabase, `aal2`, rolul/hold-ul curent,
autorizarea, rate limits, ownership-ul și idempotency înainte de a porni
runnerul. Apoi verificatorul server-side:

1. validează schema, căile, dimensiunile și hash-urile;
2. selectează profilul WASM și pachetul exact cerute de versiunea exercițiului;
3. creează un sandbox curat fără rețea, secrete sau environment sensibil;
4. rulează din nou testele publice și apoi testele private;
5. sanitizează rezultatul și numai apoi actualizează attemptul/progresul.

WebAssembly nu este considerat singur o limită de securitate. Runnerul WASM
rulează într-un sandbox exterior disposable, fără rețea sau secrete, cu limite
de timp, CPU, memorie, output, fișiere și procese și cu terminare controlată de
părinte.

Numai un grading request finalizat de server cu status `completed` poate crea
attemptul imuabil; numai verdictul server-side `passed` poate acorda punctele și
actualiza progresul. O eroare de infrastructură, versiune, runtime sau worker
nu este răspuns greșit, nu creează attempt și rămâne retryable. Serverul nu are
voie să accepte un verdict trimis de browser.

Un `completed` cu verdict learner diferit de `passed` creează un attempt cu zero
puncte. Modulul 1 nu acordă credit parțial: toate testele autoritative cerute
trebuie să treacă. Runnerul întoarce verdict și dovezi; punctele sunt derivate de
logica serverului din regula publicată, nu acceptate din runner sau client.

## Feedback

Verdictele terminale cauzate de soluția learner sunt:

```text
passed
tests_failed
syntax_error
runtime_error
time_limit_exceeded
memory_limit_exceeded
output_limit_exceeded
```

Erorile de schemă/path/bytes sunt respinse înaintea jobului. Eșecurile de
sandbox, protocol, runtime/manifest sau dependență sunt rezultate de
infrastructură retryable, nu verdicte learner și nu creează attempt.

Feedbackul learner este în română și include faza, un cod stabil, numărul de
teste publice trecute/eșuate și îndrumarea permisă. Pentru testele publice poate
include traceback sanitizat și locații din fișierele learner. Pentru testele
private include numai categoria comportamentului și un mesaj pedagogic; nu
divulgă sursa testului, valori-oracol, fișiere protejate, nume interne sau căi
server. Output-ul și traceback-ul sunt trunchiate la limita profilului.

Un mesaj generic de infrastructură cere reîncercare și nu sugerează că soluția
este greșită. Două rulări autoritative ale aceleiași intrări trebuie să întoarcă
același verdict pedagogic.

## Autentificarea și TOTP sunt în afara WASM

- Înregistrarea, loginul, verificarea JWT/session, enroll/challenge/verify TOTP,
  recovery și step-up MFA sunt responsabilitatea Fastify/Supabase.
- Aceste fluxuri sunt testate de suitele backend, nu de verificatorul
  curriculumului.
- Niciun JWT, refresh token, secret TOTP, cod de șase cifre, service key sau
  credential nu este montat ori transmis runnerului.
- Runnerul primește numai fișierele exercițiului, fixture-urile permise și un ID
  intern opac al jobului.
- Un exercițiu Python nu poate autentifica utilizatorul și rezultatul său nu
  poate înlocui verificarea MFA.

## CURR-WASM-001 — Înghețarea contractului educațional WASM

Prerechizite: CURR-STD-001 și
[G-WASM](../../todo/08-execution/02-phase-gates.md) din planul Coditza. Taskul
rămâne `blocked` până când verificarea server-side autoritativă are contract/
OpenAPI generat și un profil runtime verificabil. Frontendul și preview-ul din
browser nu sunt prerechizite pentru acest task.

Raportul G-WASM trebuie să confirme explicit PRD-WASM-001, ARC-WASM-001,
SUP-WASM-001, FAST-WASM-001, API-WASM-001, QA-WASM-001 și OPS-WASM-001; simpla
existență a fișierelor de plan nu satisface prerechizitul.

- [ ] Înregistrează versiunea exactă Pyodide/CPython și hash-ul tuturor
      asseturilor self-hosted.
- [ ] Înregistrează sursele oficiale Pyodide/CPython folosite și data
      verificării; nu copiază o versiune din memorie.
- [ ] Consumă `python-wasm-runtime.lock.json` produs de ARC-WASM-001 și creează
      `runtime-allowlist.json` curricular, fără intervale de versiuni sau URL-uri
      CDN.
- [ ] Copiază limitele tehnice autoritative; păstrează limitele curriculare mai
      mici unde acest contract le cere.
- [ ] Dovedește că instalarea/downloadul dinamic și rețeaua sunt dezactivate.
- [ ] Documentează interfața viitorului Web Worker module și faptul că rezultatul
      său va rămâne provizoriu; nu implementează frontend și nu alege framework.
- [ ] Creează schema canonică goală pentru `python_code`, inclusiv trimiterea
      multi-fișier și regulile de cale.
- [ ] Creează un fixture valid minimal și fixture-uri invalide pentru traversal,
      symlink/hard link, duplicate, coliziune ASCII-case, extensie, import,
      path length, file count, bytes și coliziune cu o cale read-only.
- [ ] Creează o pereche public/private de teste sintetice fără conținut de curs
      și dovedește că pachetul public destinat viitorului browser nu conține
      testul privat ori soluția; nu implementează un bundle frontend.
- [ ] Rulează aceeași trimitere de două ori pe server și de două ori în
      verificatorul local WASM; cere același rezumat pentru testele publice.
      Când va exista un runner browser, paritatea lui devine obligatorie și
      invalidează acest task până la revalidare.
- [ ] Dovedește că numai serverul poate finaliza statusul `completed`, crea
      attemptul și actualiza progresul pentru verdictul `passed`.
- [ ] Dovedește că un eșec de infrastructură nu creează attempt și nu este notat
      ca răspuns greșit.
- [ ] Dovedește fixture-ul `sqlite3` sau blochează C06–C08 și capstone-ul; nu
      folosește Python nativ ca excepție.
- [ ] Scanează workerul, requesturile, logurile și rapoartele pentru teste
      private, soluții, JWT-uri, chei și materiale TOTP.
- [ ] Documentează comanda locală care rulează același profil WASM pentru autori.

Dovada minimă este profilul lock-uit, schemele și fixture-urile fără conținut
real, rapoarte de paritate server/local, contractul preview-ului browser viitor
și teste negative care confirmă separarea artefactelor protejate și a
autentificării.
