# ADR-003: Workspace, Audit-Chain und Debug-Nachweise

Status: Akzeptiert

## Kontext

Ein Workflow-Ergebnis muss nachvollziehbar sein. Nach Redo darf für Folgeschritte
nur der letzte gültige Stand zählen; alte Versuche müssen trotzdem prüfbar
bleiben.

## Entscheidung

Jeder Run bekommt ein frisches Unterverzeichnis unterhalb des zentralen
Arbeitsverzeichnisses. Jeder Schritt besitzt einen Ordner mit `current.md` als
gültigem Stand und `attempts/attempt-XX/` für historische Versuche.

`CHAIN.jsonl` ist eine append-only Audit-Chain mit Hash-Verkettung. Der Run
beginnt mit `GENESIS` und endet mit `WORKFLOW_SEALED` oder `WORKFLOW_ABORTED`.
Zusätzlich werden `audit-manifest.json`, `hash-chain.json` und
`audit-summary.md` geschrieben.

Debug-Dateien werden unabhängig von der UI-Sichtbarkeit geschrieben. Der
Debug-Modus steuert nur, ob die App diese Dateien im Inspector anzeigt.

## Konsequenzen

- Redo ersetzt `current.md`, behält alte Attempts aber nachvollziehbar.
- Downstream-Schritte lesen nur verbundene aktuelle Artefakte.
- Die Audit-Chain kann mit `script/verify_audit.py` ohne App geprüft werden.
- Es gibt noch keine echte kryptografische Signatur; `signature-placeholder.txt`
  enthält den vorbereiteten Endhash.
