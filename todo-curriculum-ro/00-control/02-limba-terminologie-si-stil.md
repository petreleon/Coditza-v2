# Limbă, terminologie și stil

## Reguli obligatorii

- Toate titlurile, explicațiile, cerințele și feedbackurile pentru cursant sunt
  în română, UTF-8, normalizare Unicode NFC.
- Diacriticele corecte `ă`, `â`, `î`, `ș`, `ț` sunt obligatorii.
- Identificatorii Python, importurile, numele fișierelor, comenzile și output-ul
  literal rămân în engleză.
- La prima apariție, termenul canonic românesc este urmat de termenul englezesc
  între paranteze. Ulterior se folosește termenul românesc.
- Nu se traduce mecanic codul și nu se inventează echivalente diferite între
  capitole.
- Propozițiile sunt directe, iar paragrafele au o singură idee centrală.
- Se folosește persoana a doua singular într-o formă neutră: „vei separa”,
  „observă”, „rulează”.
- Raw HTML nu apare în Markdown.

## Termeni structurali Coditza

Se folosesc consecvent:

- `modul`;
- `capitol`;
- `secțiune teoretică`;
- `exercițiu`;
- `quiz` sau, în explicația inițială, „test de verificare (quiz)”.
- `exercițiu Python verificat` pentru tipul tehnic `python_code`;
- `rezultat local provizoriu` pentru rularea viitoare în browser;
- `verificare autoritativă` pentru verdictul server-side.

„Lecție” nu este sinonim structural pentru capitol sau secțiune.

## Termeni arhitecturali canonici

| Română | Engleză |
| --- | --- |
| arhitectură software | software architecture |
| responsabilitate | responsibility |
| limită arhitecturală | architectural boundary |
| cuplare | coupling |
| coeziune | cohesion |
| strat | layer |
| monolit modular | modular monolith |
| inversarea dependențelor | dependency inversion |
| injectarea dependențelor | dependency injection |
| port | port |
| adaptor | adapter |
| caz de utilizare | use case |
| entitate | entity |
| obiect-valoare | value object |
| depozit / repository | repository |
| rădăcină de compoziție | composition root |
| compromis | trade-off |
| atribut de calitate | quality attribute |

Glosarul final poate decide între „depozit” și `repository`, dar apoi folosește
o singură formă în tot modulul.

## CURR-STD-001 — Stabilirea standardelor editoriale și tehnice

Prerechizite: CURR-PLAN-002 și acceptarea publicului.

- [ ] Confirmă titlul, publicul, prerechizitele și politica quizurilor.
- [ ] Confirmă că exemplele sunt framework-neutral.
- [ ] Alege nivelul de limbaj Python compatibil cu profilul Pyodide/CPython
      furnizat de `G-WASM`; versiunea și hash-urile runtime sunt înghețate în
      CURR-WASM-001, nu inventate aici.
- [ ] Alege și fixează exact toolchain-ul autorului: managerul de mediu/pachete,
      `pytest`, formatterul/linterul și type checker-ul. CPython nativ este doar
      ajutor de authoring și nu poate produce verdictul curricular final.
- [ ] Confirmă termenii `python_code`, Python-on-WebAssembly, test public, test
      privat, rezultat provizoriu și verificare autoritativă.
- [ ] Decide vizibilitatea repository-ului de conținut și locul protejat al
      răspunsurilor reale înainte de orice quiz.
- [ ] Confirmă termenii canonici și regulile de diacritice.
- [ ] Înregistrează deciziile și comenzile de verificare fără secrete.

Dovada minimă este un raport de standarde acceptat și un mediu de authoring
curat care poate rula un exemplu minimal, format/lint/typecheck și `pytest`.
Acceptarea în WASM aparține taskului CURR-WASM-001.
