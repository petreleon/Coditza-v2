# Contractul exact al unui capitol

Fiecare task `M1-Cxx-001` produce un pachet complet. Nu este permisă publicarea
unei teorii fără exerciții și quiz asociate.

## Metadate

- titlu românesc și slug stabil fără diacritice;
- poziție derivată din ordinea manifestului, nu introdusă duplicat;
- timp estimat;
- prerechizite;
- trei sau patru obiective măsurabile cu ID-uri stabile;
- referințe la toate artefactele ordonate;
- surse tehnice primare și data verificării.

## Teorie

- 3–6 secțiuni teoretice;
- 1.200–2.400 de cuvinte în total, dacă subiectul nu justifică explicit altă
  dimensiune;
- fiecare secțiune predă o singură idee centrală;
- fiecare concept are definiție, motiv, exemplu, limită și compromis;
- cel puțin un exemplu corect și un anti-exemplu etichetat;
- fiecare bloc Python provine dintr-un fișier testat în profilul WASM fixat;
  pseudocodul folosește bloc `text`, nu `python`;
- nicio secțiune nu prezintă structura directoarelor drept arhitectură în sine.

## Laborator Python verificat

- un checkpoint al aplicației Study Tracker;
- pași observabili, fără fișiere sau importuri ascunse;
- un pachet multi-fișier `python_code` conform
  [contractului WASM](05-contract-verificare-python-wasm.md);
- starterul compilează și trece lint; testele care trebuie să eșueze sunt
  enumerate explicit;
- starterul produce exact rezultatul public declarat, iar soluția finală trece
  testele publice și private în profilul WASM fixat;
- laboratorul nu necesită rețea, credentiale sau servicii externe;
- ceasurile, UUID-urile și persistența temporară sunt injectate sau controlate;
- trimiterea conține numai fișiere `.py` care respectă contractul canonic;
  testele, fixture-urile read-only, profilul și limitele sunt selectate de
  server, nu acceptate de la client;
- numai grading requestul server-side WASM ajuns `completed` poate crea
  attemptul, iar numai verdictul său `passed` poate actualiza progresul;
- rularea locală cu CPython nativ este ajutor pedagogic, nu dovadă pentru gate.

## Livrarea laboratorului către cursant

Sursa canonică produce atât documentul learner, cât și pachetul machine-readable
`python_code`. Transportul final urmează exact OpenAPI-ul care a trecut G-WASM
și G5; planul curricular nu inventează un endpoint și nu presupune existența
unui frontend. Fiecare laborator este autosuficient:

- `learner/labs/<checkpoint>.md` conține manifestul de fișiere al starterului,
  apoi conținutul integral al fiecărui fișier necesar în blocuri delimitate;
- același document conține comenzile, testele publice și rezultatele așteptate;
- `python-exercises/<checkpoint>/exercise.json` descrie entrypointul, profilul
  WASM, fișierele editabile/read-only, limitele, hash-urile și testele publice;
- toate importurile, fișierele de configurare și fixture-urile necesare sunt
  incluse; `…`, „restul rămâne neschimbat” și fișierele ascunse sunt interzise;
- blocurile sunt generate din sursa canonică testată, nu copiate manual;
- cursantul nu depinde de un repository, CDN, download dinamic sau serviciu
  extern pentru conținutul exercițiului;
- un viitor preview din browser primește numai pachetul public și afișează
  `Rezultat local provizoriu`; lipsa frontendului nu blochează submitul direct
  către verificatorul server-side;
- soluția completă rămâne în
  `protected-author/solutions/<checkpoint>/`, iar testele private în
  `protected-author/python-private-tests/<checkpoint>/`; niciuna nu este inclusă
  în Markdown, payload-ul learner sau bundle-ul viitorului browser.

## Exerciții Coditza

Minimum trei exerciții obligatorii:

1. recunoaștere/diagnostic;
2. aplicarea principiului într-un pachet `python_code`, inclusiv mai multe
   fișiere când obiectivul privește module sau dependențe;
3. alegerea sau justificarea unei limite/dependențe.

Sunt permise `single_choice`, `multiple_choice`, `short_text` și `python_code`.
`short_text` este folosit numai pentru token-uri ASCII deterministe sau listează
toate variantele românești intenționate; nu se notează proză prin potrivire
exactă. Un răspuns `python_code` respectă limitele, allowlistul, separarea
testelor și feedbackul din contractul WASM.

## Quiz

- minimum opt întrebări;
- folosește numai `single_choice`, `multiple_choice` și `short_text`;
- fiecare obiectiv are cel puțin o întrebare;
- include memorare, aplicare și analiză;
- `single_choice` are de regulă patru opțiuni paralele;
- `multiple_choice` are 4–6 opțiuni, minimum două corecte și două incorecte;
- fără dublă negație, capcane, „toate variantele” sau indicii din lungime;
- nicio întrebare nu este copiată textual din exerciții;
- întrebările cu output folosesc cod executat și verificat în profilul WASM;
- feedbackul românesc explică principiul, nu doar „corect/incorect”.

## Chei și răspunsuri

- Artefactele cursantului nu conțin answer spec, opțiuni marcate sau soluții.
- `clientRef`-urile sunt neutre (`opt_a`), niciodată `correct_option`.
- Cheile reale sunt separate de materialele cursantului.
- Dacă repository-ul este public sau vizibilitatea este nerezolvată, taskul de
  quiz se blochează înainte de commitul cheilor reale.
- Soluțiile laboratorului și justificarea distractorilor sunt artefacte pentru
  autor/reviewer, nu material implicit pentru cursant.
- Pentru `python_code`, testele private și soluția sunt echivalentul protejat al
  cheii. Clientul nu trimite și nu poate alege testele, runtime-ul, limitele ori
  verdictul.

## Manifest viitor

Pachetul viitor va conține:

```text
chapter.json
theory/*.md
examples/<checkpoint>/
learner/labs/<checkpoint>.md
python-exercises/<checkpoint>/exercise.json
python-exercises/<checkpoint>/starter/
python-exercises/<checkpoint>/readonly/
python-exercises/<checkpoint>/public-tests/
learner/exercises.json
learner/quiz.json
protected-author/assessment-keys.json
protected-author/python-private-tests/<checkpoint>/
protected-author/solutions/<checkpoint>/
coverage.json
references.json
```

Manifestele JSON sunt validate cu scheme versionate care folosesc
`additionalProperties: false`, ID-uri/ref-uri unice, fără căi `..`, fără slug-uri
duplicate și fără UUID-uri de bază de date scrise manual.

## CURR-FORMAT-001 — Implementarea contractului de conținut

Prerechizite: CURR-WASM-001 și gate-ul tehnic Coditza
[G5](../../todo/08-execution/02-phase-gates.md). Taskul nu pornește dintr-o
schemă presupusă: folosește OpenAPI-ul de authoring generat de backend-ul local
care a trecut G5 și contractul `python_code` care a trecut G-WASM.

- [ ] Creează structura canonică goală pentru modul/capitol/checkpoint.
- [ ] Creează scheme JSON versionate pentru modul, capitol, exerciții, quiz,
      coverage și referințe, toate cu `additionalProperties: false`.
- [ ] Leagă schemele de contractul din OpenAPI generat de aceeași revizie
      Coditza; câmpurile necunoscute și union-urile de întrebare nesuportate sunt
      respinse, nu transformate implicit.
- [ ] Permite exact `single_choice`, `multiple_choice`, `short_text` și
      `python_code` în exerciții; schema quizului permite numai primele trei.
- [ ] Definește schema canonică `python_code` și maparea validată la OpenAPI,
      inclusiv versiunea definiției, profilul runtime, entrypointul, fișierele
      multi-fișier, limitele și digestul bundle-ului.
- [ ] Validează căile POSIX ASCII, caracterele/lungimea, duplicatele,
      coliziunile după ASCII case-folding, extensia `.py`, cele 1–16 fișiere,
      limitele 64 KiB/fișier și 256 KiB total și coliziunile cu read-only conform
      contractului WASM.
- [ ] Pentru conținutul canonic folosește ref-uri stabile și neutre. Întrebările
      și opțiunile folosesc `clientRef` conform
      `^[A-Za-z][A-Za-z0-9_-]{0,63}$`; cheile protejate folosesc
      `correctOptionRef` sau `correctOptionRefs`, niciodată UUID-uri DB.
- [ ] Definește `learner/exercises.json` și `learner/quiz.json` fără answer spec,
      marcaje de corectitudine, feedback care divulgă răspunsul sau justificări
      de distractori.
- [ ] Definește `protected-author/assessment-keys.json` cu ref-ul resursei,
      ref-ul itemului, answer spec și feedback/rationale; generatorul face join
      după ref numai în memorie pentru payload-ul administrativ protejat și nu
      scrie cheile în payload-uri publice, loguri sau rapoarte.
- [ ] Pentru `short_text`, fixează
      `nfkc_ascii_ws_ascii_lower_v1`: Unicode NFKC, înlocuirea secvențelor
      U+0009…U+000D și U+0020 cu un singur U+0020, trim pentru U+0020 și
      transformarea numai a ASCII `A-Z` în `a-z`; literele non-ASCII rămân
      case-sensitive.
- [ ] Aplică limitele din OpenAPI-ul curent: inclusiv lungimile fiecărui câmp,
      2–20 opțiuni pentru choice, 1–20 răspunsuri acceptate de 1–4.000 de
      caractere pentru `short_text`, 1–100 întrebări per quiz, corp HTTP brut
      de maximum 1 MiB și definiție canonică de maximum 1.000.000 de bytes.
- [ ] Validează ref-uri, slug-uri, ID-uri, ordine, căi și obiective unice.
- [ ] Creează un pachet minimal valid și câte un fixture invalid pentru fiecare
      familie de reguli.
- [ ] Creează verificarea snippet → regiune sursă Python și interzice copierea
      manuală care poate deriva.
- [ ] Generează Markdown-ul laboratorului din starterul canonic și dovedește
      într-un director gol că toate fișierele pot fi reconstruite.
- [ ] Generează pachetul public WASM și manifestul protejat din aceeași sursă;
      dovedește că soluția și testele private nu apar în pachetul learner.
- [ ] Rulează starterul și soluția de două ori prin verificatorul local WASM;
      cere rezultatul public declarat pentru starter, toate testele trecute
      pentru soluție și rezumate canonice identice între rulări.
- [ ] Scanează artefactele learner, logurile și rapoartele pentru chei, soluții,
      nume de câmpuri private și ref-uri care indică răspunsul corect.
- [ ] Definește o singură comandă locală deterministă pentru validarea
      structurală și execuția în același profil WASM ca serverul.
- [ ] Rulează validarea de două ori și cere rezultate identice.

Dovada este un contract testat pe fixture-uri, compatibil cu OpenAPI-ul Coditza
al aceleiași revizii, fără conținut real și fără chei în ieșirile publice.
