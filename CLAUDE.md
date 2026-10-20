# CLAUDE.md

Guidance for Claude Code (and humans) working in this repository. See
`README.md` for architecture, build steps and where things live.

## Workflow: issue → PR → CI, for every change

Every change, however small, goes through this loop. Never commit directly
to `main`.

1. **Open an issue first** with `gh issue create`, with labels that fit:
   - Type: `bug`, `enhancement` or `documentation`.
   - Area: `engine` (MongolEngine package), `keyboard` (extension UI),
     `app` (container app), `lexicon` (data or generator), `linguistics`
     (script/orthography rules), `ci` (workflows and tooling).
   - If a label does not exist yet, create it with `gh label create`
     rather than skipping it.
   - Say what is wrong or missing and what "done" looks like.
2. **Branch from `main`.** Name the branch `<type>/<issue-number>-<slug>`,
   e.g. `feat/12-vowel-harmony`.
3. **Open a PR for the change** with `gh pr create`. Put `Closes #<issue>`
   in the body so merging closes the issue. Keep one concern per PR.
4. **Explain what changed, with evidence screenshots**, in the PR body (or a
   comment for anything added later):
   - A short "What changed" list, and the before/after behaviour.
   - **UI or typing-behaviour changes** (keyboard, app, transliteration
     output): before and after iOS Simulator screenshots of the *same*
     input. Build "before" from the base commit and "after" from the PR head.
   - **Engine-only, tooling or docs changes**: a screenshot of the green CI
     job, plus the relevant test-output lines (e.g. `Executed 84 tests, with
     0 failures`).
   - Store images on the orphan branch `pr-evidence` as
     `pr-<number>/<name>.png`, never on `main`. Embed them with
     `https://github.com/Akiko0210/MongolianKeyboard/blob/pr-evidence/pr-<number>/<name>.png?raw=true`.
5. **Run CI and keep it green.**
   - Locally, before pushing: `cd Packages/MongolEngine && swift test`.
   - On GitHub, the workflow in `.github/workflows/` runs on every PR. Check
     it with `gh pr checks`, and fix any failure before asking for review
     or merging.
   - Never merge with failing or skipped checks.

## Engineering notes

- Engine logic lives in `Packages/MongolEngine` (pure Swift, no UIKit). Add or
  adjust tests in `Packages/MongolEngine/Tests/MongolEngineTests/` for any
  change to mappings, tokenizing, folding, ranking or script rules.
- `LatinKey.fold` and `fold_key()` in `tools/generate_lexicon.py` must stay in
  sync. Regenerate `lexicon.tsv` after changing either one.
- Script/orthography rules (vowel harmony, positional forms, FVS/MVS/NNBSP)
  must cite a source (Unicode `StandardizedVariants.txt`, a grammar such as
  Poppe's *Grammar of Written Mongolian*, or the GB/T 25914 encoding
  standard) in a code comment or the PR body. Never guess an encoding.
- The `.xcodeproj` is generated: edit `project.yml`, then run `xcodegen generate`.
