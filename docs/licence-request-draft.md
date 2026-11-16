# Licence request — draft, not sent

Send to the author of [tugstugi/mongolian-nlp](https://github.com/tugstugi/mongolian-nlp),
ideally as a GitHub issue on that repository so the answer is public and
citable, which a private email is not.

This is the only thing blocking submission. Do not send data-rights questions
to Apple; resolve them at the source.

---

**Subject:** Licence for the datasets in mongolian-nlp?

Hello,

I'm building MongolKey, a free offline iOS keyboard for traditional Mongolian
script. It uses two things derived from your repository: word-pair counts from
`bichig2cyrillic/lyrics.txt.gz` for next-word suggestions, and word frequencies
from `datasets/eduge.csv.gz` for ranking.

The repository doesn't carry a LICENSE file, so by default I can't redistribute
anything derived from it inside an App Store binary. Before I either replace
the data or drop the features, I wanted to ask directly:

1. Would you be willing to add a licence to the repository — MIT, Apache-2.0 or
   CC-BY would all work for me?
2. If the underlying data isn't yours to relicense (the README credits Bolorsoft
   for the Eduge news set), could you point me to who holds it?
3. Failing both — would you object to me shipping only derived *counts*
   (word frequencies and word-pair counts), with no article or lyric text
   included, and attribution to the repository?

I'm happy with attribution anywhere you'd like it, and to share back the
corrections I've made: I've found and removed conversion artefacts in the
lyrics-derived forms, and I can send that list if it's useful to you.

Thank you for publishing these resources either way — they're the reason this
keyboard works at all.
