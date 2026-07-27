# Verificare tehnică și pregătirea publicării

## Sursa canonică viitoare

După autorizare, conținutul va avea o sursă canonică versionată, de forma:

```text
content/ro-RO/python-architecture/
├── module.json
├── glossary.json
├── python-wasm-runtime.lock.json
├── runtime-allowlist.json
├── chapters/
├── examples/
├── python-exercises/
├── learner/
└── protected-author/
```

Numele exact poate fi modificat în CURR-STD-001. Payload-urile generate nu se
editează manual. Cheile reale nu intră într-un repository public.

## Contractul clientului local de authoring

Clientul este un utilitar one-off al curriculumului, nu un endpoint nou în
Coditza. El respectă OpenAPI-ul generat de backend-ul local:

- fixează revizia backend, hash-ul `docs/api/openapi.json`, capul migrațiilor și
  hash-ul manifestului curricular înainte de prima mutație;
- validează fiecare request și response față de acel OpenAPI și se oprește la
  drift; nu ghicește câmpuri sau rute;
- pornește numai după reset local curat și după crearea unei identități admin
  locale prin mecanismul aprobat de planul tehnic;
- ține un state manifest separat pentru fiecare environment fingerprint. Acesta
  mapează `contentRef → {databaseId, Location, version}` și
  `operation/contentRef → {UUID Idempotency-Key, canonicalBodyHash, result}`;
- generează chei UUID deterministe din namespace-ul unic mediului, operație,
  content ref și hash-ul manifestului; aceeași operație reluată folosește
  aceeași cheie și exact același corp canonic;
- nu copiază ID-uri sau state manifest între două reseturi/medii și nu scrie
  tokenul admin, answer spec sau chei de evaluare în log;
- creează topologic modulul, apoi capitolele, apoi teoria/exercițiile/quizurile,
  folosind ID-ul părintelui numai în rută și capturând `Location`, versiunea și
  mapările `{clientRef,id}` din response;
- unește learner item + cheia protejată numai în memorie. Trimite
  `correctOptionRef`/`correctOptionRefs`, iar UUID-urile copiilor sunt generate
  de server și capturate din response;
- completează definițiile quizurilor, apoi publică de la frunze spre rădăcină:
  teorie/exercițiu/quiz, capitol, modul;
- la timeout/pierdere de response, reia cu aceeași cheie și același corp. Dacă
  cheia a expirat, reconciliază întâi prin GET administrativ folosind ID-ul
  salvat sau combinația unică părinte + slug/ref + hash; dacă existența nu poate
  fi dovedită univoc, se oprește și nu creează orbește cu o cheie nouă;
- după o a doua încărcare de la reset curat, compară snapshoturile semantic:
  ignoră numai ID-uri/timestamps/request IDs generate, dar cere conținut,
  ordine, statusuri și ref-uri identice.
- pentru `python_code`, trimite numai fișierele editabile și versiunea
  definiției cerută de OpenAPI; nu trimite teste, runtime, limite ori verdict
  furnizate de client;
- tratează numai verdictul verificatorului server-side WASM ca autoritativ.
  Autentificarea/admin/TOTP se încheie în Fastify/Supabase înaintea runnerului;
  niciun material Auth nu intră în jobul WASM.

## Pipeline local obligatoriu

1. validează schemele și ref-urile;
2. verifică Markdown/linkuri/raw HTML;
3. verifică Unicode și terminologia;
4. compară snippet-urile cu sursa Python;
5. compilează și rulează toolchain-ul de authoring fixat;
6. validează profilul, allowlistul, căile, limitele și digesturile WASM;
7. rulează de două ori testele publice/private ale fiecărui checkpoint și
   testele cumulative în verificatorul local WASM;
8. validează exercițiile/quizurile și coverage;
9. generează payload-urile de două ori și cere diff gol;
10. resetează Supabase local;
11. creează conținutul prin calea administrativă locală aprobată;
12. trimite cel puțin o soluție validă și una invalidă `python_code` prin API și
    verifică verdictul autoritativ server-side WASM;
13. parcurge modulul ca learner și dovedește ordinea/lipsa cheilor, testelor
    private și materialelor Auth/TOTP;
14. arhivează doar rapoarte fără răspunsuri secrete.

## M1-PUBLISH-001 — Pregătirea și verificarea locală a publicării

Prerechizite: M1-TECH-QA-001, M1-LANG-QA-001 și M1-ASSESS-QA-001 sunt curate pe
aceeași revizie și același hash de manifest; M1-FIX-001 este `complete` sau
`not applicable`; planul tehnic Coditza a trecut
[G5](../../todo/08-execution/02-phase-gates.md), inclusiv Auth/admin local,
migrații, rutele de authoring și OpenAPI-ul generat, și
[G-WASM](../../todo/08-execution/02-phase-gates.md), inclusiv verificarea
server-side autoritativă.

- [ ] Creează manifestul final al modulului și al celor opt capitole.
- [ ] Verifică slug-uri/ref-uri/ordine unice și toate câmpurile obligatorii.
- [ ] Înregistrează revizia backend, capul migrațiilor și hash-urile OpenAPI,
      profil runtime, allowlist, bundle-uri, manifest curricular și rapoarte QA;
      oprește execuția dacă diferă.
- [ ] Resetează baza locală și creează identitatea admin fixture prin calea
      aprobată; dovedește autorizarea înainte de prima creare.
- [ ] Generează determinist payload-urile și le validează față de OpenAPI-ul
      curent, inclusiv limitele 1 MiB/1.000.000 bytes.
- [ ] Validează toate pachetele `python_code`; soluțiile trec testele publice și
      private de două ori în profilul WASM, iar starterele au exact starea
      publică declarată.
- [ ] Folosește un client de authoring one-off peste API-ul existent; nu adaugă
      un endpoint generic de import/export în produs.
- [ ] Creează state manifestul environment-scoped cu ref → ID/Location/version
      și operație → UUID idempotency key/hash/rezultat.
- [ ] Unește cheile numai în memorie, rezolvă ref-urile prin contractul
      `clientRef`/`correctOptionRef(s)` și păstrează ieșirile learner curate.
- [ ] Încarcă numai în Supabase/Coditza local prin API-ul administrativ aprobat.
- [ ] Creează în ordinea părinte → copil, capturează toate mapările returnate și
      publică în ordinea copil → capitol → modul.
- [ ] Testează response pierdut/retry cu aceeași cheie și același corp, conflict
      pentru corp diferit și reconcilierea sigură după expirarea cheii.
- [ ] Repetă de la al doilea reset local cu un state manifest nou și cere
      snapshot semantic identic, exceptând numai valorile generate declarate.
- [ ] Parcurge identitate → catalog → capitol → teorie/exercițiu/quiz → progres.
- [ ] Trimite prin API fișiere multi-fișier valide/invalide și dovedește că
      serverul, nu clientul, selectează runtime-ul, testele și verdictul.
- [ ] Pentru submitul valid, cere `202 Accepted`, urmărește `Location` până la
      `completed` și compară attemptul imuabil; nu interpretează preview-ul sau
      starea `queued`/`running` ca succes.
- [ ] Dovedește că o eroare de infrastructură nu creează attempt și că numai un
      request server-side `completed` cu verdict `passed` actualizează
      progresul.
- [ ] Dovedește că learner-ul nu vede chei, soluții sau fișiere de autor.
- [ ] Scanează payload-urile publice, logurile, rapoartele și inventarul pentru
      answer specs, răspunsuri, teste private, tokenuri, materiale TOTP și date
      sensibile.
- [ ] Creează un raport cu comenzile, exit code-urile, hash-urile și snapshotul
      semantic, fără secrete sau răspunsuri.

Acest task rămâne `blocked` dacă G5 și G-WASM nu sunt demonstrate. Nu
implementează frontend, nu configurează Chrome și nu publică în development sau
production.
Orice promovare hosted va avea un task separat, țintă exactă și aprobarea
explicită a utilizatorului după ce planul tehnic Coditza permite acest lucru.
