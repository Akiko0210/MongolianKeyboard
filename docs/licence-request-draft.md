# Licence request — draft, not sent

Send to the author of [tugstugi/mongolian-nlp](https://github.com/tugstugi/mongolian-nlp)
(Erdene-Ochir Tuguldur, public GitHub email tugstugi@gmail.com), or better as a GitHub issue on that repository so the answer is public and
citable, which a private email is not.

This is the only thing blocking submission. Do not send data-rights questions
to Apple; resolve them at the source.

---

**Subject:** Licence for the datasets in mongolian-nlp?

Hello,

I'm building MongolKey, a free, offline iOS keyboard for traditional Mongolian
script. It uses data derived from your mongolian-nlp repository:

- About 25,000 word forms (Cyrillic with traditional-script spelling) taken
  from `bichig2cyrillic/lyrics.txt.gz`, which fill in inflected words my base
  dictionary lacks.
- Word-pair counts from those lyrics and from `datasets/eduge.csv.gz`, used for
  next-word suggestions.
- Word frequencies from the same two sets, used to rank suggestions.

No article or lyric text is shipped, only the word list, its spellings and the
counts.

The repository has no LICENSE file, so by default I can't redistribute anything
derived from it inside an App Store app. Before I replace the data or drop
these features, I wanted to ask you directly:

1. Would you be willing to add a licence to the repository? MIT, Apache-2.0 or
   CC-BY would all work for me.
2. If the underlying data isn't yours to relicense (the README credits
   Bolorsoft for the Eduge news set), could you point me to who holds it?
3. If neither is possible, would you object to my shipping only the derived
   word list and counts described above, with attribution to your repository?

I'm happy to give attribution wherever you'd like. I can also share back
corrections: I found and removed conversion artefacts in the lyrics-derived
forms, and I can send you that list if it's useful.

Thank you for publishing these resources either way. They're a large part of
why this keyboard works at all.
