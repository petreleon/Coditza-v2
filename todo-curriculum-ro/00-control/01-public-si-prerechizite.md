# Public, prerechizite și rezultate

## Public țintă propus

Cursant adult aflat la nivel începător-avansat sau intermediar timpuriu. Poate
scrie programe Python mici, dar tinde să pună logica, I/O-ul și starea în
aceleași funcții sau fișiere.

## Prerechizite obligatorii

Cursantul poate:

- folosi variabile, condiții, bucle, funcții și excepții;
- defini clase simple și `dataclass`;
- crea și importa module/pachete;
- folosi colecții și type hints de bază;
- rula comenzi într-un terminal;
- citi un test Python simplu;
- folosi Git la nivelul clone/status/diff/commit.

Modulul începe cu un diagnostic nepunctat, publicat ca auto-verificare în
secțiunea introductivă de teorie, nu ca quiz/attempt Coditza. Dacă un cursant nu
poate explica un import, o funcție pură și un test cu trei faze, materialul îl
trimite la prerechizitele Python; nu încearcă să predea simultan sintaxa de bază.
Un diagnostic care execută Python folosește testele publice ale profilului WASM
și este etichetat provizoriu; nu creează progres.

## Rezultat general

La final, cursantul poate transforma incremental un script într-o aplicație
modulară, testabilă și ușor de schimbat, fără a introduce complexitate care nu
este justificată.

## Competențe măsurabile

Cursantul poate:

1. separa o cerință funcțională de un atribut de calitate;
2. identifica responsabilități, cuplare, coeziune și limite;
3. organiza codul în pachete cu o direcție clară a dependențelor;
4. modela reguli de domeniu fără I/O și framework;
5. orchestra cazuri de utilizare prin contracte explicite;
6. defini porturi cu `Protocol` și injecta adaptoare;
7. schimba persistența fără a modifica regulile domeniului;
8. alege teste unitare, de contract, integrare și arhitectură;
9. documenta o decizie și compromisurile ei într-un ADR;
10. argumenta când un monolit modular este suficient și când nu este.

## Accesibilitate pedagogică

- Fiecare concept nou are definiție, exemplu corect, anti-exemplu și consecință.
- Diagramele au alternativă textuală.
- Culoarea nu este singurul purtător de sens.
- Exercițiile `python_code` sunt construite pentru filesystem-ul virtual WASM
  și nu presupun un sistem de operare anume.
- Comenzile locale sunt fallback pedagogic; rezultatul acceptat de Coditza vine
  din verificatorul server-side WASM.
- Cerințele evită expresii de tip „este evident” sau „pur și simplu”.
