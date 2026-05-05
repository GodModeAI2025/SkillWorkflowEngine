# ADR-001: Native Skill-Workflow-Player

Status: Akzeptiert

## Kontext

SkillShortCuts soll nicht nur ein Chat-Frontend sein. Es soll Prozesse aus
mehreren Skills ausführen, Zwischenstände nachweisen und manuelle QS-/Redo-
Schleifen ermöglichen.

## Entscheidung

Die App wird als native macOS-App mit SwiftUI umgesetzt. Der zentrale Zustand
liegt im `AppStore`; `PromptBuilder`, `GatekeeperService`, `RunWorkspaceWriter`
und `LLMClient` kapseln jeweils eigene Verantwortlichkeiten.

Die UI folgt dem Intent/Operate/Check-Modell:

- Links: Daten, Auftrag, Arbeitsverzeichnis und Skill-Bibliothek.
- Mitte: Pipe Canvas mit Skills, Personas, Rollen und Abhängigkeiten.
- Rechts: Inspector, Preview, Debugger, Settings und Erklärfunktion.

## Konsequenzen

- Funktionen sind direkt mit App-Zustand und Tests verbindbar.
- Native Controls, Menüs, Toolbar und App-Lifecycle können genutzt werden.
- Web-/Electron-Komplexität entfällt.
- Für echte LLM-Ausführung bleiben API-Keys erforderlich.
