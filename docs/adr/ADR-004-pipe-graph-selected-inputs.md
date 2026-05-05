# ADR-004: Pipe-Graph, selektive Inputs und parallele Ausführung

Status: Akzeptiert

## Kontext

Sequenzielle Skills reichen nicht aus. In echten Beratungsprozessen können
mehrere Module unabhängig aus derselben Source arbeiten; spätere Module können
gezielt nur bestimmte frühere Ergebnisse lesen.

## Entscheidung

Jeder Schritt hat einen Input-Modus:

- `Source only`: liest nur Auftrag und Datenkontext.
- `Previous`: liest den direkten Vorgänger.
- `All previous`: liest alle vorherigen aktuellen Artefakte.
- `Selected`: liest explizit ausgewählte frühere Knoten.

Der Scheduler berechnet Ausführungsebenen und kann unabhängige Knoten parallel
starten. Der Gatekeeper prüft ungültige Selected-Eingänge, unbekannte Knoten,
Selbst-/Zukunftsreferenzen und doppelte IDs vor dem Run.

## Konsequenzen

- Der Graph bleibt technisch abbildbar und auditierbar.
- Knoten 5 kann gezielt Knoten 1 lesen, ohne Knoten 2 bis 4 mitzunehmen.
- Redo invalidiert transitive downstream-Abhängigkeiten.
- Die UI zeigt Input-Policy und Abhängigkeiten im Canvas und im Prompt.
