# Scop și decizii curriculare

## Decizii date explicit de utilizator

- Limba materialelor pentru cursant este româna.
- Primul modul creat este despre arhitectură în Python.
- Produsul rămâne Coditza.
- Fiecare capitol conține teorie, exerciții și quiz.
- Verificarea laboratoarelor și exercițiilor Python folosește Python-on-
  WebAssembly; un verdict CPython nativ nu este acceptare Coditza.
- Verificarea autoritativă rulează server-side. Un eventual preview din browser
  este numai provizoriu și nu actualizează progresul.

## Propuneri care trebuie acceptate în CURR-PLAN-001

- Titlu: **Arhitectură software în Python**.
- Public: cursanți care cunosc Python de bază, dar nu au studiat arhitectura.
- Aplicație continuă: **Study Tracker**, o aplicație pentru activități de studiu.
- Opt capitole, de la responsabilități și module până la testare și ADR-uri.
- Exemple independente de framework; biblioteca standard este preferată.
- Laboratoarele Python sunt pachete multi-fișier `python_code`, fără rețea sau
  secrete, cu teste publice și private deterministe.
- Exercițiile conceptuale folosesc `single_choice`, `multiple_choice` și
  `short_text`; exercițiile de implementare folosesc `python_code`.
- Quizurile sunt inițial necronometrate, cu încercări nelimitate, prag 70% și
  minimum opt întrebări. Utilizatorul poate modifica această politică.

## Arhitecturi și idei incluse

- arhitectură stratificată;
- monolit modular;
- arhitectură hexagonală / porturi și adaptoare;
- principiul inversării dependențelor și dependency injection manual;
- MVC ca model de separare pentru interfețe web;
- arhitectură bazată pe evenimente și microservicii doar comparativ;
- alegerea unei arhitecturi proporționale cu problema.

Modulul nu susține că există o singură arhitectură „cea mai bună”. Fiecare
alegere este evaluată prin cerințe, atribute de calitate, cost și compromisuri.

## În afara scopului Modulului 1

- sintaxa Python pentru începători absoluți;
- predarea FastAPI, Django sau Flask ca obiectiv principal;
- implementarea efectivă a microserviciilor distribuite;
- Kubernetes, cloud, service mesh sau DevOps avansat;
- Domain-Driven Design complet;
- CQRS și event sourcing de producție;
- review manual al codului ca cerință pentru progresul în MVP;
- folosirea runtime-ului WASM pentru register, login, JWT, TOTP, recovery sau
  orice alt flux de autentificare;
- implementarea frontendului ori a preview-ului browser în acest plan
  curricular;
- publicarea în producție în timpul acestei sarcini de planificare.

## Regula schimbării

Orice modificare a publicului, numărului de capitole, aplicației continue,
politicii de evaluare, profilului WASM, allowlistului sau limitelor platformei
se notează în `STATUS.md`, în registru și în roadmap înainte de redactarea
materialelor afectate. Schimbarea profilului invalidează toate dovezile
`python_code` produse cu profilul anterior.
