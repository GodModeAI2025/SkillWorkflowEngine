# SkillShortCuts

Native macOS App für kontrollierte, ausführbare und nachvollziehbare
KI-Skillworkflows. Das Repository heißt aktuell noch `SkillWorkflowEngine`, das
gebaute App-Bundle und das SwiftPM-Produkt heißen `SkillShortCuts`.

SkillShortCuts ist im Kern ein Skillworkflow-Player: Links werden Daten, Ordner
und ein strukturierter Auftrag eingebracht. In der Mitte wird ein Beraterteam aus
`WER` und `WAS` zusammengestellt. Rechts wird geprüft, ausgeführt, freigegeben
oder mit Feedback erneut gelaufen.

```text
Intent                  Operate                         Check
Daten + Auftrag  ->     WER + WAS + Rolle + QS    ->    Review, Redo, Audit
```

## Was in dieser Version steckt

- native macOS App statt Web-Prototyp
- echte Ausführung über OpenAI oder Anthropic API-Key
- Import echter AIConsultant-Skills, Personas, Agenten und Standardworkflows
- Drag-and-drop Beraterteam aus Skill (`WAS`), Persona (`WER`), Rolle und QS-Modus
- strukturierte Eingabe für Ziel, Kontext, Ergebnis und Bewertungskriterien
- manuelle Freigabe, Auto-QS, Redo mit Feedback und sichtbarer Wartezustand im Workflow
- dynamischer Play-Button: Startet den Workflow oder gibt den wartenden Schritt frei
- Abbruch/Reset für einen laufenden Workflow
- zentral konfigurierbares Arbeitsverzeichnis mit frischem Unterordner je Run
- Debug-Modus für Input, Systemprompt, Userprompt, Output, Review und QS je Schritt
- Audit v2 mit `CHAIN.jsonl`, Genesis, Event-Hashes, Seal/Abort und Standalone-Verifier
- NWEB-Farbsystem und App-Icon für die native App

## Warum

Freie KI-Chats sind flexibel, aber schwer kontrollierbar:

- derselbe Auftrag wird von unterschiedlichen Menschen unterschiedlich formuliert
- Zwischenergebnisse und Feedback verschwinden im Chatverlauf
- es ist schwer nachzuweisen, welcher Input, welcher Prompt und welches Ergebnis
  zu einem finalen Artefakt geführt haben
- Prompt Injection und Aufgabenabweichungen sind spät sichtbar

SkillShortCuts reduziert diese Freiheitsgrade bewusst. Der Mensch wählt Daten,
Workflow, Skills, Rollen und QS-Punkte aus. Die App baut daraus reproduzierbare
Prompts, führt echte LLM-Calls aus und schreibt jeden Durchlauf in ein eigenes
Arbeitsverzeichnis.

## App-Aufbau

| Bereich | Zweck |
|---|---|
| Links: Auftrag & Daten | Arbeitsverzeichnis, Eingabeordner, AIConsultant-Bibliothek, strukturierter Auftrag |
| Mitte: Beraterteam | Drag-and-drop Workflow aus Skills, Personas, Rollen und QS-Modi |
| Rechts: Inspector | Prompt-Vorschau, Run-Status, Gatekeeper, Debug, Ergebnisse, Review und Nachweisdateien |

## Typischer Ablauf

1. Arbeitsverzeichnis wählen. Dort legt die App pro Durchlauf ein neues
   Unterverzeichnis an.
2. Eingabedaten hinterlegen: Ordner, Datei- oder Textkontext.
3. Auftrag strukturiert erfassen: Ziel, Kontext, gewünschtes Ergebnis,
   Kriterien und optionaler Zusatz.
4. AIConsultant-Bibliothek laden oder vorhandene Workflows nutzen.
5. Beraterteam zusammenstellen: pro Schritt Skill, Persona, Rolle, Modell und
   QS-Modus festlegen.
6. Workflow starten. Die App erzeugt Run-Plan, Gatekeeper-Report, Prompts und
   Arbeitsverzeichnis.
7. Ergebnisse je Schritt prüfen. Bei manueller QS wartet der Schritt sichtbar
   auf Freigabe oder Feedback.
8. Bei Feedback läuft nur der betroffene Schritt erneut. Das neue Ergebnis wird
   `current.md`; alte Versuche bleiben unter `attempts/`.
9. Nach Abschluss wird der Run versiegelt und kann mit dem Standalone-Verifier
   geprüft werden.

## Intent / Operate / Check

### Intent

Der Auftrag ist nicht nur ein Freitextfeld. Er wird strukturiert erfasst:

- `Ziel`
- `Kontext`
- `Gewünschtes Ergebnis`
- `Kriterien`
- optionaler `Freitext-Zusatz`

Damit bleibt der Auftrag beschreibbar, aber stabiler als ein reiner Chat-Prompt.

### Operate

Ein Schritt kombiniert:

- `WAS`: Skill, Job oder Agent, der die Arbeit ausführt
- `WER`: optionale Persona für Perspektive, Haltung und Stil
- `Rolle`: Verhalten des Schritts in der Sequenz
- `QS`: ob der Schritt manuell, automatisch oder gar nicht geprüft wird

Mehrere Schritte werden hintereinander ausgeführt. Nachfolgende Schritte erhalten
nicht den kompletten Chatverlauf, sondern gezielt die aktuellen Artefakte aus den
vorherigen Schritten.

### Check

Nach jedem relevanten Schritt kann der Nutzer:

- das Ergebnis freigeben
- Feedback erfassen und den Schritt erneut ausführen
- das aktuelle Artefakt im Arbeitsverzeichnis prüfen
- im Debug-Modus Eingangsdateien, Prompts, Outputs, QS und Reviews je Schritt einsehen
- die Gatekeeper- und Auditdaten einsehen

### Toolbar und Run-Steuerung

Der Play-Button oben rechts ist kontextsensitiv:

- vor dem Lauf startet er den Workflow
- während eines laufenden Schritts zeigt die Prozessliste den aktiven Schritt
  mit Spinner
- wenn ein Schritt auf manuelle Freigabe wartet, wirkt der Play-Button wie
  `Freigeben und weiter`
- bei Redo-Feedback wird nur der wartende Schritt mit Eingangsmaterial,
  vorherigem Ergebnis und Korrekturprompt erneut ausgeführt
- der Abbruch-Button beendet den aktuellen Workflow, schreibt `WORKFLOW_ABORTED`
  in die Chain und setzt den inhaltlichen Run-Zustand zurück

## Rollen

Rollen sind prompt-relevant. Sie sind nicht nur UI-Labels.

| Rolle | Bedeutung |
|---|---|
| `LEAD` | Führt den Schritt, erstellt das primäre Artefakt und macht Annahmen sichtbar. |
| `SUPPORT` | Ergänzt bestehende Ergebnisse, vertieft Teilaspekte und liefert zu. |
| `CHALLENGE` | Prüft kritisch auf Risiken, Lücken, Widersprüche und schwache Annahmen. |
| `SECOND OPINION` | Erstellt eine unabhängige Zweitmeinung auf Basis von Input und Vorartefakten. |
| `LEKTORAT` | Vereinheitlicht Sprache, Struktur, Tonalität und Lesbarkeit. |
| `FINALIZER` | Erstellt das finale Ergebnis aus den freigegebenen aktuellen Artefakten. |

### Warum mehrere Rollen in Sequenz Sinn machen

Ein Workflow ist nicht nur eine lineare To-do-Liste. Er modelliert ein
Beratungsgremium:

- Ein `LEAD` erstellt die erste belastbare Fassung.
- Ein `SUPPORT` ergänzt mit einer bestimmten Fachperspektive, etwa Security,
  Betrieb, Einkauf oder Kommunikation.
- Ein zweiter `SUPPORT` direkt danach kann sinnvoll sein, wenn zwei verschiedene
  Disziplinen zuliefern sollen, ohne die Verantwortung des Lead zu übernehmen.
- Eine `CHALLENGE`-Rolle sucht anschließend bewusst Lücken und Widersprüche.
- `SECOND OPINION` eignet sich, wenn eine unabhängige Alternativsicht entstehen
  soll, statt nur den bestehenden Text zu korrigieren.
- Ein späterer `LEAD` kann sinnvoll sein, wenn ein neuer Ergebnisabschnitt
  beginnt, etwa von Analyse zu Entscheidungsgrundlage oder von Review zu
  Präsentation.

Ergebnisse werden nicht nur als "letzter Chat-Text" behandelt. Jeder Schritt hat
ein eigenes Verzeichnis und einen gültigen aktuellen Stand. Nachfolgende Skills
bekommen die freigegebenen aktuellen Artefakte vorheriger Schritte gezielt als
Kontext.

## Beispiel: Software-Lifecycle-Review

Ein möglicher Workflow für einen Quellcode-Ordner:

| Schritt | Rolle | Skill/Persona | Ergebnis |
|---|---|---|---|
| 1 | `LEAD` | Architektur Review als Enterprise Architect | Risiken, Modularität, Verantwortlichkeiten, ADR-Bedarf |
| 2 | `SUPPORT` | Security Review als Security Architect | Security-Befunde, Token-/Secret-Risiken, Schutzmaßnahmen |
| 3 | `CHALLENGE` | Kritische Prüfung als unabhängiger Reviewer | Widersprüche, unklare Evidenz, offene Annahmen |
| 4 | `LEKTORAT` | Redaktionelle Verdichtung | Lesbare, konsistente Review-Fassung |
| 5 | `FINALIZER` | PR-/ADR-Schreiber | PR-Beschreibung, ADR-Vorschläge und nächste Umsetzungsschritte |

Jeder Schritt kann manuell oder automatisch geprüft werden. Wird bei Schritt 4
Feedback gegeben, ersetzt nur Schritt 4 seinen gültigen Stand; die vorherigen
Schritte bleiben als Herkunft erhalten.

## Workflow-Modi

| Modus | Zweck |
|---|---|
| `Ausführen` | Auftrag eingeben, Workflow starten, Schritte freigeben oder Redo anstoßen. |
| `Bearbeiten` | Skills, Personas, Rollen, Reihenfolge, Modelle und QS konfigurieren. |
| `Prüfen` | Arbeitsverzeichnis, Gatekeeper, Artefakte, Hash-Kette und Auditdaten kontrollieren. |

## Arbeitsverzeichnis

Jeder Lauf bekommt ein frisches Unterverzeichnis unterhalb des zentralen
Arbeitsverzeichnisses. Wird ein Skill per Feedback erneut ausgeführt, ersetzt das
neue Ergebnis den gültigen aktuellen Stand (`current.md`). Alte Versuche bleiben
unter `attempts/` erhalten.

```text
SkillShortCuts-Workspace/
  <workflow-name>/
    run-<timestamp>-<id>/
      workflow.json
      run-plan.json
      CHAIN.jsonl
      gatekeeper-report.json
      input-folder-context.md
      run-state.json
      audit-manifest.json
      hash-chain.json
      audit-summary.md
      signature-placeholder.txt
      01-architecture-review/
        current.md
        current-state.json
        latest-review.md
        attempts/
          attempt-01/
            request-system.md
            request-user.md
            output.md
          attempt-02/
            request-system.md
            request-user.md
            previous-output.md
            review-feedback.md
            output.md
```

Wichtige Regel:

- `current.md` ist der gültige Stand eines Skills.
- Redo ersetzt `current.md`.
- Historische Versuche bleiben nachvollziehbar unter `attempts/`.
- Nachfolgende Skills bekommen die aktuellen Artefakte vorheriger Skills, nicht
  jeden alten Versuch.

Wenn Reihenfolge, Skillauswahl oder Input geändert werden, wird der alte
Run-Kontext invalidiert und ein neuer Lauf legt wieder ein frisches Verzeichnis an.

## Gatekeeper

Vor dem Lauf erzeugt die App einen lokalen Gatekeeper-Report. Der aktuelle MVP ist
regelbasiert und prüft unter anderem:

- fehlende Workflow-Schritte
- fehlender oder ungültiger Eingabeordner
- unklarer Auftrag
- fehlender Provider-API-Key
- Prompt-Injection-ähnliche Muster in Nutzereingaben
- Prompt-Instruktionen im Ordnerkontext

Das Ergebnis ist in der UI sichtbar und liegt als `gatekeeper-report.json` im
Run-Verzeichnis.

## Debug-Modus

Der Debug-Modus ist in den Einstellungen aktivierbar. Wenn er aktiv ist, zeigt die
Run-Ansicht pro Schritt, welche Dateien wirklich in den Schritt hinein- und aus
ihm herausgegangen sind:

- `input-folder-context.md` als Datenkontext
- `request-system.md` und `request-user.md` als echte LLM-Prompts
- `previous-output.md` und `review-feedback.md` bei Redo-Läufen
- `output.md` und `current.md` als Versuchsausgabe und gültiger Stand
- `quality-system.md`, `quality-user.md` und `quality-report.md` bei Auto-QS
- `review.md` und `latest-review.md` bei manueller Freigabe oder Redo

Der Modus steuert die Sichtbarkeit in der UI. Die Nachweisdateien werden weiterhin
im Arbeitsverzeichnis geschrieben, damit Audit und Debug auf derselben Wahrheit
basieren.

## Nachweis und Herkunft

SkillShortCuts schreibt für jeden Lauf lokale Nachweisdateien:

- `CHAIN.jsonl`: append-only Audit-Chain für jeden relevanten Zustandswechsel
- `workflow.json`: gespeicherte Workflow-Konfiguration
- `run-plan.json`: konkrete Ausführungsreihenfolge
- `audit-manifest.json`: Metadaten und Datei-Hashes
- `hash-chain.json`: geordnete Hash-Kette über Run-Artefakte
- `audit-summary.md`: lesbare Zusammenfassung
- `signature-placeholder.txt`: vorbereiteter Endhash für spätere Signatur

### Audit v2: `CHAIN.jsonl`

Die Datei `CHAIN.jsonl` ist die eigentliche Audit-Spur. Jeder Eintrag enthält:

- Sequenznummer
- Zeitstempel
- festen Event-Typ
- optionale Referenz auf Schritt, Skill oder Workflow
- strukturierte Daten mit Artefakt-Hashes
- `prev_hash`
- `entry_hash`

Der erste Eintrag ist `GENESIS` und versiegelt Workflow, Run-Plan,
Gatekeeper-Report, verwendete Skills, Personas und Modellkonfiguration. Danach
loggen die Run-Schritte unter anderem:

- `GATEKEEPER_RUN`
- `STEP_STARTED`
- `PROMPT_BUILT`
- `LLM_REQUEST_SENT`
- `ARTIFACT_WRITTEN`
- `QS_STARTED`
- `QS_COMPLETED`
- `REVIEW_REQUIRED`
- `REVIEW_APPROVED`
- `REVIEW_REDO_REQUESTED`
- `STEP_COMPLETED`
- `WORKFLOW_SEALED`
- `WORKFLOW_ABORTED`

Ein abgeschlossener Run wird mit `WORKFLOW_SEALED` versiegelt. Ein abgebrochener
Run wird mit `WORKFLOW_ABORTED` beendet, bevor die UI den Zustand zurücksetzt.

| Event | Bedeutung |
|---|---|
| `GENESIS` | Startzustand mit Workflow, Run-Plan, Skills, Personas, Provider und Gatekeeper-Hashes |
| `GATEKEEPER_RUN` | Vorprüfung vor der Ausführung |
| `STEP_STARTED` | Schritt wurde gestartet und bekommt ein Arbeitsverzeichnis |
| `PROMPT_BUILT` | System- und Userprompt wurden erzeugt und gehasht |
| `LLM_REQUEST_SENT` | Ein echter Provider-Call wurde vorbereitet/abgesetzt |
| `ARTIFACT_WRITTEN` | Output, Review, QS oder State-Datei wurde geschrieben |
| `REVIEW_REQUIRED` | Schritt wartet auf manuelle Freigabe oder Feedback |
| `REVIEW_APPROVED` | Nutzer hat den aktuellen Stand freigegeben |
| `REVIEW_REDO_REQUESTED` | Nutzerfeedback erzeugt einen neuen Versuch für denselben Schritt |
| `STEP_COMPLETED` | Schritt ist abgeschlossen und sein `current.md` ist der gültige Stand |
| `WORKFLOW_SEALED` | Run wurde abgeschlossen und semantisch versiegelt |
| `WORKFLOW_ABORTED` | Run wurde abgebrochen und der UI-Zustand zurückgesetzt |

### Standalone-Verifier

Die Chain kann ohne App und ohne externe Dependencies geprüft werden:

```bash
python3 script/verify_audit.py <run-dir>/CHAIN.jsonl --report
```

Strenger Modus für abgeschlossene Runs:

```bash
python3 script/verify_audit.py <run-dir>/CHAIN.jsonl --report --require-seal
```

Der Verifier prüft:

- lückenlose Sequenz
- `prev_hash` gegen den vorherigen `entry_hash`
- neu berechneten `entry_hash`
- Genesis-Block
- terminalen Seal/Abort
- referenzierte Artefakt-Hashes für bekannte Pfad-/Hash-Paare

### Grenzen des Nachweises

Das ist noch keine produktive Signatur- oder Trust-Infrastruktur. Die Chain
beweist Integrität und Manipulationserkennung, nicht fachliche Korrektheit.
Sie schafft aber eine stabile Struktur, um später Pakete zu signieren, extern zu
verankern oder in Governance-Prozesse zu übergeben.

Konkret bedeutet das:

- Die Chain zeigt, ob die dokumentierte Geschichte nachträglich verändert
  wurde.
- Sie beweist nicht, dass ein LLM-Ergebnis fachlich richtig ist.
- Sie ersetzt keine Berechtigungs-, Signatur- oder Archivierungsstrategie.
- Sie ist ein lokaler, menschenlesbarer Audit-Pfad, der später signiert oder
  extern verankert werden kann.

## AIConsultant-Import

Die App kann eine AIConsultant-Bibliothek von `/private/tmp/AIConsultant` oder aus
einem frei konfigurierten Pfad laden. Gelesen werden unter anderem:

- `agentic-fabrik-skill/SKILL.md`
- `references/agents/*.md`
- `references/job-skills/*/PROFILE.md`
- `references/persona-skills/*/PROFILE.md`
- `references/standard-workflows.md`
- `references/lektor-anleitung.md`

Damit werden echte Skills, Personas, Agenten und Standardworkflows in der UI
angeboten.

## AI Provider

| Provider | Aktuell konfiguriertes Default-Modell |
|---|---|
| OpenAI | `gpt-5.5` |
| Anthropic | `claude-opus-4-1-20250805` |

API-Keys können in der App erfasst oder per Environment Variable gesetzt werden:

```bash
OPENAI_API_KEY=sk-... ./script/build_and_run.sh
ANTHROPIC_API_KEY=sk-ant-... ./script/build_and_run.sh
```

API-Keys werden nicht in Workflow-JSON-Dateien geschrieben.

## Build und Start

Voraussetzungen:

- macOS 14 oder neuer
- Swift 5.9+ / Xcode 15+
- OpenAI- oder Anthropic-API-Key für echte Ausführung

App bauen und starten:

```bash
./script/build_and_run.sh
```

Start verifizieren:

```bash
./script/build_and_run.sh --verify
```

Das Script baut mit SwiftPM, erstellt `dist/SkillShortCuts.app` und startet die
native macOS App.

## Projektstruktur

```text
Sources/SkillShortCutsNative/
  App/              App entrypoint und AppDelegate
  Models/           Workflow-, Run-, Gatekeeper- und Library-Modelle
  Stores/           AppStore mit Zustand und Run-Orchestrierung
  Views/            Auftrag, Team Composer, Inspector, Run-UI
  Services/         LLM-Client, PromptBuilder, Gatekeeper, WorkspaceWriter
  Support/          Theme, Interaction Helpers, String Helpers
script/             build_and_run.sh
```

## Aktuelle MVP-Grenzen

- Gatekeeper ist lokal und regelbasiert, noch kein Multi-Modell-Gatekeeper.
- Nachweisdateien enthalten Hashes, aber noch keine echte kryptografische Signatur.
- DOCX/PPTX-Erzeugung ist im nativen MVP noch kein eigener Artifact Writer.
- MCP-Konfiguration wurde für diese native MVP-Runde bewusst herausgenommen.
- Berechtigungsmodelle für fertige Workflows sind konzeptionell vorgesehen, aber
  noch nicht produktiv umgesetzt.

## Lizenz

Licensed under the [Apache License 2.0](LICENSE).
