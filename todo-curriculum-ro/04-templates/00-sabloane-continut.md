# Șabloane pentru implementarea viitoare

## Șablon capitol

```text
Titlu:
Slug:
Poziție:
Timp estimat:
Prerechizite:
Obiective:
Secțiuni teoretice ordonate:
Checkpoint:
Runtime profile ref/hash:
Pachet python_code/digest:
Teste publice/private:
Exerciții:
Quiz:
Surse și data verificării:
Coverage:
Comenzi și rezultate:
Review-uri:
```

## Șablon secțiune teoretică

```text
Concept și obiectiv:
De ce contează:
Definiție:
Exemplu testat:
Anti-exemplu testat:
Limită/compromis:
Întrebare de verificare:
Surse:
```

## Șablon learner pentru exercițiu

```text
ID:
Obiectiv principal:
Nivel cognitiv:
Tip Coditza:
Prompt românesc:
Opțiuni/clientRef sau răspuns determinist:
Verificarea ambiguității:
Pentru python_code: ref către manifestul multi-fișier:
```

Fișierul learner nu conține cheia, feedback condiționat de corectitudine,
explicația autorului sau justificarea opțiunilor.

## Șablon learner pentru quiz item

```text
ID:
Quiz/chapter:
Obiectiv principal:
Nivel cognitiv:
Tip:
Prompt:
Opțiuni neutre:
Dovada execuției snippetului, dacă există:
Reviewer:
```

Acest fișier se află sub `learner/` și nu conține answer spec, marcaje de
corectitudine, feedback condiționat sau justificări ale distractorilor.

## Șablon manifest learner pentru `python_code`

```text
Schema/version:
Exercise ref + definition version:
Objective refs:
Runtime profile ref:
Entrypoint:
Starter source paths:
Policy for additional .py paths:
Reserved read-only paths:
Public test IDs:
Allowed extensions/import profile:
Source limits: 1–16 files / 65.536 bytes per file / 262.144 bytes total:
Timeout/memory/output limits:
Files + role + SHA-256:
Expected public starter result:
Public feedback codes:
Bundle SHA-256:
```

Nu include teste private, soluția, `hiddenTestSetRef`, oracole sau verdict
pretins. Căile sunt POSIX relative ASCII și trec regulile de lungime, caractere
și coliziune după ASCII case-folding.

## Șablon protejat pentru verificarea `python_code`

```text
Exercise ref + definition version:
Runtime profile ref/hash:
Public test IDs/hashes:
Private test set ref + IDs/hashes:
Reference solution digest:
Expected starter public summary:
Expected solution full summary:
Coverage objective → public/private tests:
Două rulări local WASM:
Două rulări server WASM:
Leak scan:
Reviewer:
```

Acest artefact rămâne sub `protected-author/`. Rapoartele publice pot conține
numai digesturi și numărători, nu sursa testelor private sau oracolele.

## Șablon protejat pentru cheia unui item

```text
Resource ref:
Item ref:
Tip:
correctOptionRef / correctOptionRefs / acceptedAnswers:
Normalization version, numai pentru short_text:
Feedback corect:
Feedback incorect:
Rationale pentru fiecare distractor:
Dovada verificării:
Reviewer:
```

Acest fișier se află numai sub `protected-author/`, se unește cu itemul learner
după ref-uri stabile și nu este copiat în Markdown, payload-uri publice, loguri
sau rapoarte.

## Șablon raport

```text
Task:
Autor:
Scope permis:
Prerechizite:
Artefacte:
Comenzi + exit code:
Runtime profile/hash:
Package digests:
WASM local/server canonical results:
Coverage:
Review tehnic:
Review lingvistic:
Review evaluare:
Probleme deschise:
Status propus:
Următorul task:
```
