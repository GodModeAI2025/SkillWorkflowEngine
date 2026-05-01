# SkillShortCuts

Native macOS App fuer kontrollierte, ausfuehrbare und nachvollziehbare
KI-Skillworkflows. Das Repository heisst aktuell noch `SkillWorkflowEngine`, das
gebaute App-Bundle und das SwiftPM-Produkt heissen `SkillShortCuts`.

SkillShortCuts ist im Kern ein Skillworkflow-Player: Links werden Daten, Ordner
und ein strukturierter Auftrag eingebracht. In der Mitte wird ein Beraterteam aus
`WER` und `WAS` zusammengestellt. Rechts wird geprueft, ausgefuehrt, freigegeben
oder mit Feedback erneut gelaufen.

```text
Intent                  Operate                         Check
Daten + Auftrag  ->     WER + WAS + Rolle + QS    ->    Review, Redo, Audit
```

## Warum

Freie KI-Chats sind flexibel, aber schwer kontrollierbar:

- derselbe Auftrag wird von unterschiedlichen Menschen unterschiedlich formuliert
- Zwischenergebnisse und Feedback verschwinden im Chatverlauf
- es ist schwer nachzuweisen, welcher Input, welcher Prompt und welches Ergebnis
  zu einem finalen Artefakt gefuehrt haben
- Prompt Injection und Aufgabenabweichungen sind spaet sichtbar

SkillShortCuts reduziert diese Freiheitsgrade bewusst. Der Mensch waehlt Daten,
Workflow, Skills, Rollen und QS-Punkte aus. Die App baut daraus reproduzierbare
Prompts, fuehrt echte LLM-Calls aus und schreibt jeden Durchlauf in ein eigenes
Arbeitsverzeichnis.

## App-Aufbau

| Bereich | Zweck |
|---|---|
| Links: Auftrag & Daten | Arbeitsverzeichnis, Eingabeordner, AIConsultant-Bibliothek, strukturierter Auftrag |
| Mitte: Beraterteam | Drag-and-drop Workflow aus Skills, Personas, Rollen und QS-Modi |
| Rechts: Inspector | Prompt-Vorschau, Run-Status, Gatekeeper, Debug, Ergebnisse, Review und Nachweisdateien |

## Intent / Operate / Check

### Intent

Der Auftrag ist nicht nur ein Freitextfeld. Er wird strukturiert erfasst:

- `Ziel`
- `Kontext`
- `Gewuenschtes Ergebnis`
- `Kriterien`
- optionaler `Freitext-Zusatz`

Damit bleibt der Auftrag beschreibbar, aber stabiler als ein reiner Chat-Prompt.

### Operate

Ein Schritt kombiniert:

- `WAS`: Skill, Job oder Agent, der die Arbeit ausfuehrt
- `WER`: optionale Persona fuer Perspektive, Haltung und Stil
- `Rolle`: Verhalten des Schritts in der Sequenz
- `QS`: ob der Schritt manuell, automatisch oder gar nicht geprueft wird

Mehrere Schritte werden hintereinander ausgefuehrt. Nachfolgende Schritte erhalten
nicht den kompletten Chatverlauf, sondern gezielt die aktuellen Artefakte aus den
vorherigen Schritten.

### Check

Nach jedem relevanten Schritt kann der Nutzer:

- das Ergebnis freigeben
- Feedback erfassen und den Schritt erneut ausfuehren
- das aktuelle Artefakt im Arbeitsverzeichnis pruefen
- im Debug-Modus Eingangsdateien, Prompts, Outputs, QS und Reviews je Schritt einsehen
- die Gatekeeper- und Auditdaten einsehen

## Rollen

Rollen sind prompt-relevant. Sie sind nicht nur UI-Labels.

| Rolle | Bedeutung |
|---|---|
| `LEAD` | Fuehrt den Schritt, erstellt das primaere Artefakt und macht Annahmen sichtbar. |
| `SUPPORT` | Ergaenzt bestehende Ergebnisse, vertieft Teilaspekte und liefert zu. |
| `CHALLENGE` | Prueft kritisch auf Risiken, Luecken, Widersprueche und schwache Annahmen. |
| `SECOND OPINION` | Erstellt eine unabhaengige Zweitmeinung auf Basis von Input und Vorartefakten. |
| `LEKTORAT` | Vereinheitlicht Sprache, Struktur, Tonalitaet und Lesbarkeit. |
| `FINALIZER` | Erstellt das finale Ergebnis aus den freigegebenen aktuellen Artefakten. |

## Workflow-Modi

| Modus | Zweck |
|---|---|
| `Ausfuehren` | Auftrag eingeben, Workflow starten, Schritte freigeben oder Redo anstossen. |
| `Bearbeiten` | Skills, Personas, Rollen, Reihenfolge, Modelle und QS konfigurieren. |
| `Pruefen` | Arbeitsverzeichnis, Gatekeeper, Artefakte, Hash-Kette und Auditdaten kontrollieren. |

## Arbeitsverzeichnis

Jeder Lauf bekommt ein frisches Unterverzeichnis unterhalb des zentralen
Arbeitsverzeichnisses. Wird ein Skill per Feedback erneut ausgefuehrt, ersetzt das
neue Ergebnis den gueltigen aktuellen Stand (`current.md`). Alte Versuche bleiben
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

- `current.md` ist der gueltige Stand eines Skills.
- Redo ersetzt `current.md`.
- Historische Versuche bleiben nachvollziehbar unter `attempts/`.
- Nachfolgende Skills bekommen die aktuellen Artefakte vorheriger Skills, nicht
  jeden alten Versuch.

Wenn Reihenfolge, Skillauswahl oder Input geaendert werden, wird der alte
Run-Kontext invalidiert und ein neuer Lauf legt wieder ein frisches Verzeichnis an.

## Gatekeeper

Vor dem Lauf erzeugt die App einen lokalen Gatekeeper-Report. Der aktuelle MVP ist
regelbasiert und prueft unter anderem:

- fehlende Workflow-Schritte
- fehlender oder ungueltiger Eingabeordner
- unklarer Auftrag
- fehlender Provider-API-Key
- Prompt-Injection-aehnliche Muster in Nutzereingaben
- Prompt-Instruktionen im Ordnerkontext

Das Ergebnis ist in der UI sichtbar und liegt als `gatekeeper-report.json` im
Run-Verzeichnis.

## Debug-Modus

Der Debug-Modus ist in den Einstellungen aktivierbar. Wenn er aktiv ist, zeigt die
Run-Ansicht pro Schritt, welche Dateien wirklich in den Schritt hinein- und aus
ihm herausgegangen sind:

- `input-folder-context.md` als Datenkontext
- `request-system.md` und `request-user.md` als echte LLM-Prompts
- `previous-output.md` und `review-feedback.md` bei Redo-Laeufen
- `output.md` und `current.md` als Versuchsausgabe und gueltiger Stand
- `quality-system.md`, `quality-user.md` und `quality-report.md` bei Auto-QS
- `review.md` und `latest-review.md` bei manueller Freigabe oder Redo

Der Modus steuert die Sichtbarkeit in der UI. Die Nachweisdateien werden weiterhin
im Arbeitsverzeichnis geschrieben, damit Audit und Debug auf derselben Wahrheit
basieren.

## Nachweis und Herkunft

SkillShortCuts schreibt fuer jeden Lauf lokale Nachweisdateien:

- `CHAIN.jsonl`: append-only Audit-Chain fuer jeden relevanten Zustandswechsel
- `workflow.json`: gespeicherte Workflow-Konfiguration
- `run-plan.json`: konkrete Ausfuehrungsreihenfolge
- `audit-manifest.json`: Metadaten und Datei-Hashes
- `hash-chain.json`: geordnete Hash-Kette ueber Run-Artefakte
- `audit-summary.md`: lesbare Zusammenfassung
- `signature-placeholder.txt`: vorbereiteter Endhash fuer spaetere Signatur

### Audit v2: `CHAIN.jsonl`

Die Datei `CHAIN.jsonl` ist die eigentliche Audit-Spur. Jeder Eintrag enthaelt:

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
Run wird mit `WORKFLOW_ABORTED` beendet, bevor die UI den Zustand zuruecksetzt.

### Standalone-Verifier

Die Chain kann ohne App und ohne externe Dependencies geprueft werden:

```bash
python3 script/verify_audit.py <run-dir>/CHAIN.jsonl --report
```

Der Verifier prueft:

- lueckenlose Sequenz
- `prev_hash` gegen den vorherigen `entry_hash`
- neu berechneten `entry_hash`
- Genesis-Block
- terminalen Seal/Abort
- referenzierte Artefakt-Hashes fuer bekannte Pfad-/Hash-Paare

Das ist noch keine produktive Signatur- oder Trust-Infrastruktur. Die Chain
beweist Integritaet und Manipulationserkennung, nicht fachliche Korrektheit.
Sie schafft aber eine stabile Struktur, um spaeter Pakete zu signieren, extern zu
verankern oder in Governance-Prozesse zu uebergeben.

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

API-Keys koennen in der App erfasst oder per Environment Variable gesetzt werden:

```bash
OPENAI_API_KEY=sk-... ./script/build_and_run.sh
ANTHROPIC_API_KEY=sk-ant-... ./script/build_and_run.sh
```

API-Keys werden nicht in Workflow-JSON-Dateien geschrieben.

## Build und Start

Voraussetzungen:

- macOS 14 oder neuer
- Swift 5.9+ / Xcode 15+
- OpenAI- oder Anthropic-API-Key fuer echte Ausfuehrung

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
- MCP-Konfiguration wurde fuer diese native MVP-Runde bewusst herausgenommen.
- Berechtigungsmodelle fuer fertige Workflows sind konzeptionell vorgesehen, aber
  noch nicht produktiv umgesetzt.

## Lizenz

Licensed under the [Apache License 2.0](LICENSE).
