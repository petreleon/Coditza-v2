# Proiect integrator — Study Tracker

## Livrabil pentru cursant

Cursantul construiește sau explică o variantă completă cu:

- nucleu de domeniu fără CLI, SQLite sau framework;
- cazuri de utilizare pentru creare, planificare, finalizare și progres;
- port de persistență;
- adaptoare în memorie și SQLite;
- interfață CLI;
- composition root;
- validare și erori explicite;
- teste unitare, de contract, integrare și arhitectură;
- două ADR-uri.

## Verificarea Coditza

Componenta executabilă a proiectului este un pachet multi-fișier `python_code`.
Coditza primește numai fișierele `.py` declarate și selectează server-side
definiția publicată, profilul WASM, limitele și testele. Verificatorul
autoritativ rulează testele publice și private într-un sandbox WASM curat;
numai verdictul său poate actualiza progresul. ADR-urile și rubrica sunt
artefacte learner separate, neexecutate de runner; competența ADR este evaluată
prin exercițiile/quizul conceptual și autoevaluare, nu prin potrivirea textului.

CPython nativ și viitorul preview browser cu teste publice sunt ajutoare
pedagogice, nu verdict. Repository-ul curent nu are frontend, iar capstone-ul
trebuie să poată fi trimis direct API-ului server-side care a trecut G-WASM.
Testele private și soluția nu intră în artefactele learner.

## Etape

1. rulează testele de caracterizare;
2. separă pachetele;
3. modelează domeniul;
4. implementează cazurile de utilizare;
5. definește portul și adaptorul în memorie;
6. adaugă CLI-ul/composition root;
7. adaugă SQLite;
8. rulează în WASM contractele și testele arhitecturale;
9. adaugă interfața/raportul nou;
10. scrie ADR-urile și autoevaluarea.

## Rubrică de autoevaluare

Fiecare criteriu este `0 = absent`, `1 = parțial`, `2 = demonstrat`:

- regulile domeniului sunt independente;
- direcția dependențelor este verificată;
- cazurile de utilizare au contracte;
- ambele adaptoare trec același contract;
- composition root este singurul loc de conectare;
- erorile sunt mapate la limite;
- testele aleg nivelul potrivit;
- ADR-urile includ compromisuri reale;
- schimbarea interfeței/persistenței nu rescrie regulile;
- proiectul rulează determinist dintr-un mediu curat.
- pachetul respectă allowlistul și limitele profilului WASM;
- soluția trece testele publice și private server-side.

Rubrica este pentru învățare și nu devine scor Coditza.

## M1-CAPSTONE-001 — Integrarea proiectului final

Prerechizite: M1-C01-001…M1-C08-001 și toate gate-urile de capitol.

- [ ] Unește checkpointurile într-o progresie cumulativă coerentă.
- [ ] Construiește livrabilul numai din checkpointurile aprobate; nu rescrie
      pachetele capitolelor și raportează separat orice contradicție găsită.
- [ ] Rulează toate testele dintr-un mediu curat.
- [ ] Rulează toate testele de două ori în profilul WASM fixat și compară
      rezumatele canonice.
- [ ] Verifică fiecare pas/starter și soluție.
- [ ] Dovedește fixture-ul `sqlite3`, căile multi-fișier și lipsa rețelei,
      environmentului, secretelor și capabilităților host.
- [ ] Publică cerința și rubrica fără soluțiile/cheile autorului.
- [ ] Rulează trimiterea prin verificatorul server-side și dovedește că numai
      statusul său `completed` creează attemptul, iar numai `passed` acordă
      progres; CPython nativ sau preview-ul provizoriu nu trec gate-ul.
