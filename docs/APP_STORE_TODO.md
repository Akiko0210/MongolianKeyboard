# App Store todo

Status as of 2026-11-16. `docs/RELEASE.md` explains *why* each requirement
exists and links Apple's rules; this file is the ordered checklist.

Where things actually stand: `tools/release_preflight.py --submission` passes
every structural check — bundle metadata, fonts and their licences, the engine
resources, the extension point, no Full Access, keyboard language, iPad
orientations, matching version strings. **Two gates fail, and both are real.**

---

## 1. Blockers — cannot submit until these clear

- [ ] **Install Xcode 26 and the iOS 26 SDK.** Uploads have required it since
      28 Apr 2026. This Mac has Xcode 16.4 / iOS 18.5; preflight reports
      `found 'iphonesimulator18.5'`. Nothing else in this list can be finished
      first — archiving, device testing and validation all need it.
      *(Same blocker stops the `xcode@claude-plugins-official` plugin, whose
      source command `xcrun agent plugin path` does not exist in 16.4.)*
- [ ] **Resolve language-data redistribution rights.** See §2 — this is the
      one that can actually sink the submission, under
      [Guideline 5.2](https://developer.apple.com/app-store/review/guidelines/#intellectual-property).
- [ ] Set a Developer Team on both the app and the keyboard target, then
      archive with the iOS 26 SDK and validate in Organizer.

## 2. Language-data rights — the real risk

Three of the four data sources have **no established redistribution grant**
(`docs/DATA_PROVENANCE.md`):

| Source | What it gives | Rights |
| --- | --- | --- |
| npm `written-mongol-keyboard` 1.3.5 | base dictionary | MIT in `package.json`, **no licence covering the data** |
| `mongolian-nlp` lyrics corpus | ~25k inflected forms, pair counts | none established |
| `eduge.csv` news corpus | frequencies, bigrams | credited to Bolorsoft, no grant |
| `suragch/mongolian-datasets` | 16,789 words | **CC0-1.0 — clean** |

Pick one path:

- [ ] **Path A — go CC0-only.** Rebuild `lexicon.tsv` and `bigrams.tsv` from
      the CC0 source alone. Clears the gate outright with no correspondence
      and no waiting. Cost: coverage drops from ~45k distinct Cyrillic words
      to ~17k, and the next-word table would need a licensed replacement
      corpus, so predictions regress hardest. Measure before committing.
- [ ] **Path B — obtain the notices.** Contact sura0111 and Bolorsoft for
      written permission covering the dictionary and the news-derived tables.
      Keeps today's coverage. Cost: open-ended, and the answer may be no.
- [ ] **Path C — hybrid.** Ship CC0 data plus anything Path B secures in time,
      and keep the rest out of the bundle. Most likely to actually ship.
- [ ] Whichever path: update `DATA_PROVENANCE.md` and flip the preflight gate
      only when it is genuinely resolved. Do not copy an unrelated MIT licence
      onto these assets.

## 3. Physical-device testing

Simulator testing is done — 170 engine tests, 2 UI tests, all green. None of
that covers a real device.

- [ ] Run on a real iPhone and iPad against `docs/COMPATIBILITY.md`.
- [ ] Test in the apps people will actually use it in: Instagram, Facebook,
      Messenger, WhatsApp, Google apps. Any of them may disable third-party
      keyboards; record the result rather than assuming.
- [ ] Exercise low-memory extension restarts, rotation, VoiceOver, font
      persistence, cursor movement.
- [ ] Capture real-device screenshots — the simulator ones are not submittable.

## 4. App Store Connect

- [ ] Create the app record; register `group.*` and both bundle IDs under your team.
- [ ] Support URL and a publicly reachable privacy-policy URL (the in-app
      policy exists; it still needs to be hosted somewhere).
- [ ] Age rating, privacy and export-compliance questionnaires.
- [ ] Claim **no data collected** — true only while the keyboard stays
      Full-Access-free and offline, which preflight currently confirms.

## 5. What the listing may and may not say

The accuracy numbers are now measured, so the copy can be specific and honest.

- [ ] **Can say:** offline; no Full Access; no accounts, ads or analytics;
      52k+ dictionary entries; traditional-script spellings for common words,
      with next-word suggestions.
- [ ] **Must not say:** "all words verified", any government endorsement,
      guaranteed support in every app, or that font choice travels with sent
      text — it does not; the receiving app picks the font.
- [ ] Be careful with a single accuracy figure. Measured against the
      independent CC0 dictionary, the app agrees on **77.6%** of shared words,
      **81.8%** once the ᠶᠢ/ᠢ convention is set aside. The remainder is mostly
      ᠣ/ᠤ and ᠥ/ᠦ — the Khalkha and Chakhar written traditions differing.

## 6. Before launch, not blocking

- [ ] **Pick a script standard** (Khalkha vs Chakhar) for ᠣ/ᠤ and ᠥ/ᠦ, and say
      which one in the listing. This is a product decision, not a bug fix, and
      it accounts for most remaining disagreement with the CC0 source.
- [ ] Native-speaker review of the 388 words where we and the CC0 source
      genuinely differ (`docs/authority.tsv`, `status` column).
- [ ] Review the ~20 suspected generator artifacts the harmony filter cannot
      catch because they are harmony-consistent (бодолхийлэх, мацалхийлах,
      ташилхийлах …), listed in the 2026-10-30 cleanup commit.
- [ ] Expand `Fixtures/orthography-review.json` beyond 16 handbook examples —
      it is the only authoritative test we have, and it caught a real
      regression during the homograph re-ranking.
