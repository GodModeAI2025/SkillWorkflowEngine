# SkillWorkflowEngine

Native macOS app for composing and executing AI-powered consulting workflows. Build a virtual consulting team by combining **personas** (WER) with **skills/jobs** (WAS), define roles and quality gates, and run the workflow against OpenAI or Anthropic.

## Core Concept

```
Daten + Auftrag  ->  Beraterteam  ->  Ergebnis
                     (WER + WAS)
```

Each team member is a **ConsultantStep** that combines:
- **WER** -- a persona defining the consultant's perspective and expertise
- **WAS** -- a skill or job description defining what the consultant does
- **Role** -- LEAD, SUPPORT, CHALLENGE, or INDEPENDENT
- **Quality Gate** -- manual review, automatic, required, or none

## Features

- Drag-and-drop workflow composer with live prompt preview
- Multi-step consulting pipelines with configurable roles
- Quality gates (QS) per step -- manual approval, auto-pass, or required review
- OpenAI and Anthropic provider support with per-step model overrides
- AIConsultant library import (personas, skills, agents, standard workflows)
- Folder context injection -- point at a repo and the team analyzes it
- Run workspace with step-by-step artifact output
- Theme switching (System / Light / Dark)
- Workflow persistence as JSON

## Requirements

- macOS 14 (Sonoma) or later
- Swift 5.9+ / Xcode 15+
- An OpenAI or Anthropic API key

## Build & Run

```bash
./script/build_and_run.sh
```

Verify the app bundle launches correctly:

```bash
./script/build_and_run.sh --verify
```

The script builds via SwiftPM, stages `dist/SkillShortCuts.app`, and opens it.

## Usage

1. Set the AIConsultant library path (auto-detected at `/private/tmp/AIConsultant` if present)
2. Enter a workflow name, target folder/repo, and a global prompt (Auftragsprompt)
3. Drag a **WAS** skill into the Beraterteam
4. Optionally drag a **WER** persona onto that team slot
5. Configure role, task, prompt, output type, and QS mode per step
6. Save (`Cmd+S`) or run (`Cmd+R`) the workflow

## AI Providers

| Provider  | Default Model                    |
|-----------|----------------------------------|
| OpenAI    | `gpt-5.5`                       |
| Anthropic | `claude-opus-4-1-20250805`       |

API keys can be entered in the app or passed via environment variables:

```bash
OPENAI_API_KEY=sk-... ./script/build_and_run.sh
ANTHROPIC_API_KEY=sk-ant-... ./script/build_and_run.sh
```

Keys are never written into workflow files.

## AIConsultant Library

The app reads from an AIConsultant directory:

- `agentic-fabrik-skill/SKILL.md`
- `references/agents/*.md`
- `references/job-skills/*/PROFILE.md`
- `references/persona-skills/*/PROFILE.md`
- `references/standard-workflows.md`
- `references/lektor-anleitung.md`

## Project Structure

```
Sources/SkillShortCutsNative/
  App/              SkillShortCutsApp.swift
  Models/           WorkflowModels, LibraryModels
  Stores/           AppStore (central state)
  Views/            ContentView, TeamComposerView, DataLibraryView, InspectorRunView
  Services/         LLMClient, PromptBuilder, WorkflowPersistence,
                    RunWorkspaceWriter, AIConsultantLibraryLoader, FolderContextBuilder
  Support/          Theme, StringHelpers, InteractionSupport
script/             build_and_run.sh
data/               settings.json, AIConsultant library (gitignored)
```

## License

Licensed under the [Apache License 2.0](LICENSE).
