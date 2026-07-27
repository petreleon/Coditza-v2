# Trasabilitate și review transversal

## Matricea obligatorie

Matricea finală are câte un rând pentru fiecare obiectiv:

| Objective ID | Teorie | Exemplu/checkpoint | Exerciții | Quiz items | Pachet/teste WASM | Dovadă |
| --- | --- | --- | --- | --- | --- | --- |

Reguli:

- fiecare obiectiv apare exact o dată ca rând principal;
- fiecare obiectiv este predat, exersat și evaluat;
- un item are un singur obiectiv principal și, opțional, obiective secundare;
- niciun exercițiu/quiz nu există doar pentru a atinge un număr;
- nivelul cognitiv este marcat `recall`, `application` sau `analysis`;
- minimum jumătate din itemii modulului sunt application/analysis;
- referințele folosesc ID-uri stabile, nu poziții fragile sau UUID-uri DB.
- pentru obiectivele aplicate, coloana WASM indică `exerciseRef`,
  `runtimeProfileRef`, testele publice/private și digestul pachetului;
- o rulare CPython nativă nu poate ocupa coloana de dovadă WASM.

## M1-INTEGRATE-001 — Integrarea între capitole

Prerechizite: M1-CAPSTONE-001.

- [ ] Creează întâi un manifest de integrare cu fișierele transversale deținute,
      finding-urile și capitolele potențial afectate.
- [ ] Citește modulul cap-coadă în ordinea cursantului.
- [ ] Identifică definițiile contradictorii și introducerile duplicate.
- [ ] Verifică faptul că un capitol nu folosește un termen înainte de introducere.
- [ ] Păstrează aceeași structură și aceleași nume în toate checkpointurile.
- [ ] Verifică tranziția explicită de la un checkpoint la următorul.
- [ ] Actualizează linkurile și navigarea.
- [ ] Înaintea unei corecții într-un capitol aprobat, adaugă fișierul exact în
      manifest și schimbă M1-Cxx-001 și CG2-Cxx în `needs revalidation`.
- [ ] Pe durata acelei corecții, M1-INTEGRATE-001 este singurul owner de editare
      pentru fișierele enumerate; nu atinge alte fișiere ale capitolului.
- [ ] Rulează din nou verificările CG2 afectate și toate testele cumulative,
      apoi readuce rândurile la `complete` numai cu dovezi pe noua revizie.
- [ ] Rulează fiecare pachet afectat de două ori în același profil WASM și
      confirmă paritatea testelor publice între verificatorul local și server.

Dovada este un raport de integrare, manifestul corecțiilor, rapoartele CG2
revalidate și un diff fără modificări în afara scope-ului declarat.

## M1-TRACE-001 — Finalizarea trasabilității

Prerechizite: M1-INTEGRATE-001.

- [ ] Completează fiecare coloană a matricei.
- [ ] Respinge obiective fără teorie, practică sau evaluare.
- [ ] Respinge artefacte fără obiectiv.
- [ ] Verifică nivelul cognitiv și distribuția pe capitole.
- [ ] Verifică faptul că proiectul integrator recapitulează competențele globale.
- [ ] Produce raport automat pentru ID-uri lipsă/duplicate/referințe invalide.
- [ ] Respinge orice exercițiu Python fără pachet/digest/profil și orice test
      public sau privat fără obiectiv.

## M1-TECH-QA-001 — Review tehnic independent

Prerechizite: M1-TRACE-001. Reviewerul nu este autorul principal.

- [ ] Rulează din mediu curat fiecare checkpoint, starter și soluție în profilul
      WASM fixat; CPython nativ este numai verificare suplimentară.
- [ ] Verifică compilare, format/lint, typecheck și toate testele, apoi confirmă
      separat verdictul WASM.
- [ ] Verifică fiecare snippet față de sursa executată.
- [ ] Verifică direcția dependențelor și lipsa importurilor interzise.
- [ ] Verifică determinismul și absența rețelei/secretelor.
- [ ] Verifică allowlistul, limitele, căile, digesturile, filesystem-ul virtual
      curat și două rulări cu rezultat canonic identic.
- [ ] Compară testele publice local/server și dovedește că testele private și
      soluțiile nu apar în artefactele learner.
- [ ] Dovedește că runnerul nu primește JWT, cookie, parolă, secret/cod TOTP,
      chei Supabase sau environment sensibil.
- [ ] Verifică afirmațiile despre Python în surse oficiale primare.
- [ ] Clasifică problemele critical/high/medium/low fără a edita materialele.

## M1-LANG-QA-001 — Review lingvistic independent

Prerechizite: M1-TRACE-001. Reviewerul nu este autorul principal.

- [ ] Verifică Unicode NFC și diacriticele.
- [ ] Verifică glosarul și prima apariție bilingvă.
- [ ] Verifică acorduri, punctuație, claritate și consecvența persoanei.
- [ ] Păstrează intacte codul, comenzile și output-ul literal.
- [ ] Marchează traducerile artificiale sau termenii ambigui.
- [ ] Verifică feedbackul tuturor exercițiilor/quizurilor.
- [ ] Produce raport fără a edita materialele.

## M1-ASSESS-QA-001 — Review independent al evaluărilor

Prerechizite: M1-TRACE-001. Reviewerul are acces protejat la chei.

- [ ] Verifică exact un răspuns corect la single choice.
- [ ] Verifică minimum două corecte/două incorecte la multiple choice.
- [ ] Execută în profilul WASM orice fragment care determină un output.
- [ ] Pentru `python_code`, verifică acoperirea testelor publice/private,
      rezultatul declarat al starterului și trecerea soluției în WASM.
- [ ] Verifică lipsa capcanelor, dublei negații și indiciilor formale.
- [ ] Verifică `short_text` față de normalizarea reală Coditza.
- [ ] Verifică răspunsurile, explicațiile și justificarea distractorilor.
- [ ] Scanează materialele cursantului pentru scurgeri de chei/soluții.
- [ ] Scanează bundle-urile learner pentru teste private, oracole, trace-uri
      interne și feedback care divulgă răspunsul.
- [ ] Produce raport fără a edita materialele.

Fiecare raport final înregistrează revizia sursă și hash-ul manifestului de
conținut. Un task QA devine `complete` numai dacă raportul este curat pentru
acea revizie. Orice finding, indiferent de severitate, îi dă statusul
`needs revalidation`; critical/high blochează imediat gate-ul și publicarea.

## M1-FIX-001 — Corecție controlată după review-urile finale

Prerechizite: cele trei review-uri au produs rapoarte pe aceeași revizie. Dacă
toate sunt curate, marchează acest task `not applicable`. Dacă există cel puțin
un finding, taskul devine `next`.

- [ ] Creează o iterație `fix-NNN` și mapează fiecare finding la taskul sursă,
      fișierele exacte, owner, gate-urile și verificările afectate.
- [ ] Înainte de editare, schimbă în `needs revalidation` toate rândurile
      M1-Cxx-001, M1-CAPSTONE-001, M1-INTEGRATE-001 sau M1-TRACE-001 ale căror
      dovezi pot fi invalidate.
- [ ] Devine singurul owner temporar al fișierelor enumerate în manifest; nu
      repară finding-uri noi și nu extinde scope-ul fără actualizarea
      manifestului înainte de editare.
- [ ] Aplică numai corecțiile mapate și înregistrează finding → diff.
- [ ] Rulează din nou fiecare CG2 afectat, testele cumulative, integrarea,
      capstone-ul și trasabilitatea, după caz.
- [ ] Orice schimbare de profil, allowlist, test, starter sau soluție invalidează
      digestul pachetului și cere rerularea dovezilor WASM afectate.
- [ ] Readuce taskurile invalidate la `complete` numai după dovezi curate pe
      noua revizie.
- [ ] Marchează toate cele trei taskuri QA `needs revalidation`, chiar dacă
      schimbarea pare tehnică, apoi cere rerularea lor pe aceeași revizie nouă.
- [ ] Înregistrează revizia, hash-ul manifestului și rezultatele. Taskul devine
      `complete` numai după revalidările interne; dacă QA găsește altceva, se
      redeschide pentru următoarea iterație.

Nu se publică până când M1-FIX-001 este `complete` sau `not applicable` și toate
cele trei taskuri QA sunt din nou `complete` pe exact aceeași revizie finală.
