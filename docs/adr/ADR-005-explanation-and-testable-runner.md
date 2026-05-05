# ADR-005: Erklärfunktion und Testbarer Runner

Status: Akzeptiert

## Kontext

Die App muss für Nicht-Techniker verständlich sein. Gleichzeitig müssen
Workflow-Ausführung, Feedback-Loops und Arbeitsverzeichnisse mit echten Tests
prüfbar sein, ohne bei jedem Test echte API-Kosten und Netzwerkrisiken zu
erzeugen.

## Entscheidung

Die App erhält eine lokale Erklärfunktion. Sie erzeugt ohne LLM-Call eine
verständliche Erklärung aus dem aktuellen Zustand: Auftrag, Skill-Graph,
ausgewählter Schritt, Input-Policy, QS-Modus, Run-Status, Gatekeeper, Audit,
Workspace und wichtigste Knöpfe.

Der Runner nutzt `LLMCompleting` als Protokoll. Die produktive Implementierung
bleibt `LLMClient`; Tests injizieren einen kontrollierten Recording-Client.

## Konsequenzen

- Nutzer können sich den aktuellen Ablauf direkt in der App erklären lassen.
- Tests führen echte App-Orchestrierung aus: Workspace schreiben, Prompts bauen,
  Redo-Feedback speichern, `current.md` prüfen, Audit versiegeln und Restart
  auslösen.
- Es werden keine echten API-Keys in Tests benötigt.
- Echte Provider-Calls bleiben in der App über OpenAI/Anthropic möglich.
