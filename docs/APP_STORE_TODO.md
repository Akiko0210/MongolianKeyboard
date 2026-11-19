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
- [ ] **Resolve language-data redistribution rights.** See §2. The
      licence-clean build (#20) clears this gate at a measured accuracy cost;
      Path B would restore the legacy data. This is the
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

**All three paths were measured on 2026-11-16. Two are dead. Here is what is left.**

- [x] ~~**Path A — go CC0-only.**~~ **Dead.** Measured: CC0 covers only
      **39.4% of words actually typed**, and 89 of the 200 commonest words are
      missing (ын, сарын, оны, төрийн, монголын, болж, хуулийн). The CC0 set
      holds base forms; Mongolian is heavily suffixed and real text is mostly
      inflected. A keyboard that misses three words in five is not shippable.
      Rule-based inflection does not rescue it: монголын, газрын and болж come
      out right, but оны becomes ᠣᠨᠢᠢ and хуулийн becomes ᠬᠤᠯ ᠦᠨ.
- [x] ~~**Replace the corpora with Mongolian Wikipedia (CC BY-SA).**~~
      **Rejected on quality, not licensing.** `tools/build_wikipedia_corpus.py`
      builds it: 32,218 articles, 10.0M running words, 478,684 word pairs —
      16x the current table, properly licensed. Frequencies are excellent
      (**99.8%** coverage weighted by use, 0 of the top 200 missing). But the
      next-word predictions get measurably worse, because an encyclopedia is
      the wrong register for a keyboard:

      | after | news+lyrics | Wikipedia |
      | --- | --- | --- |
      | сайн | сайхан, байна, мэдэх | **ноён**, сайхан, дураараа |
      | байна | гэж, вэ, уу | **онд, оны**, энэ |

      Nobody types "байна онд". It broke 8 prediction tests and was reverted.
      The tool is kept: Wikipedia frequencies remain a viable licensed
      replacement for the Eduge-derived counts if that becomes the sticking
      point, and the finding is worth not rediscovering.

- [ ] **Path B — ask for a licence. Do this first; it is one email.**
      The rights picture is narrower than the September audit assumed:

      | Source | Verified 2026-11-16 | Status |
      | --- | --- | --- |
      | npm `written-mongol-keyboard` 1.3.5 | registry metadata declares **MIT**, author sura0111 | likely fine; residual risk is upstream provenance |
      | `suragch/mongolian-datasets` | **CC0-1.0** | clean |
      | `tugstugi/mongolian-nlp` | GitHub API: **no licence, no LICENSE file** | all rights reserved — **the blocker** |

      So one repository blocks submission, and it is a public collection
      titled "Useful resources for Mongolian NLP". A licence grant costs its
      author nothing and is plausibly a yes. Draft ready at
      `docs/licence-request-draft.md` — send it before building anything else.
- [x] **Path C — built (#20).** `tools/generate_lexicon.py --licence-clean`
      ships the MIT dictionary and CC0 words, Wikipedia frequencies and word
      pairs, and suffix-rule inflections; the preflight data-rights gate passes
      for it. Measured against the legacy data (which was trained on the
      evaluation text, so its numbers are an upper bound):

      | Measure | Legacy | Licence-clean |
      | --- | --- | --- |
      | Words in the lexicon | 60,077 | 43,384 |
      | News running words covered (23.9M) | 79.0% | 58.5% |
      | Top-200 news words missing | 2 | 37 |
      | 5,000 commonest words: Space commits script | 74.3% | 48.2% |
      | Same, agrees with CC0 authority (n=729) | 77.2% | 80.2% |
      | News word pairs: prediction offered / next word in top 3 (16.4M) | 82.0% / 23.8% | 60.0% / 10.0% |
      | Rule speller, authority-attested (n=5,724) | 340 | 350 |

      If the licence request (Path B) succeeds, rebuild without the flag.

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
