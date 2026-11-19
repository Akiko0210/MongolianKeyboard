//
//  mongolgen
//
//  Generates traditional-script spellings using the shipped engine — the same
//  OrthographyConverter and SuffixEngine the keyboard runs — so what is checked
//  is what users get. A second implementation in another language would drift
//  from the app and quietly validate code nobody ships.
//
//  Output is TSV on stdout: key, generated, method.
//
//    swift run mongolgen --spell  < keys.txt
//    swift run mongolgen --inflect --limit 5000
//

import Foundation
import MongolEngine

func emit(_ key: String, _ form: String, _ method: String) {
    print("\(key)\t\(form)\t\(method)")
}

let args = CommandLine.arguments
let wantSpell = args.contains("--spell")
let wantInflect = args.contains("--inflect")
let wantType = args.contains("--type")
var limit = Int.max
if let i = args.firstIndex(of: "--limit"), i + 1 < args.count, let n = Int(args[i + 1]) {
    limit = n
}

let converter = OrthographyConverter.shared
let lexicon = Lexicon.shared

guard !converter.isEmpty else {
    FileHandle.standardError.write(Data("mongolgen: orthography.tsv is empty\n".utf8))
    exit(2)
}

// Rule-based spelling: the grammar applied to a key with no dictionary help.
// This is the path the keyboard uses for a word the lexicon lacks, so it is
// the one whose accuracy is actually unknown.
if wantSpell {
    // Input is Cyrillic, one word per line — what a user actually types and
    // what the corpus is keyed by. It is folded to the engine's Latin key
    // first, exactly as the keyboard does, then spelled by the rules. The
    // Cyrillic word is emitted as the key so the result can be compared with
    // the corpus spelling for that same word.
    var n = 0
    while n < limit, let line = readLine(strippingNewline: true) {
        let word = line.trimmingCharacters(in: .whitespaces)
        if word.isEmpty { continue }
        let key = CyrillicKey.isWord(word) ? CyrillicKey.foldedLatin(word) : word
        if let spelled = SuffixEngine.ruleBased(forKey: key, spell: { converter.spell(key: $0) }) {
            emit(word, spelled, "suffix-rule")
        } else if let spelled = converter.spell(key: key) {
            emit(word, spelled, "letter-rule")
        } else {
            emit(word, "", "no-rule")
        }
        n += 1
    }
}

// Inflections built from dictionary stems by the suffix rules.
if wantInflect {
    var n = 0
    for entry in lexicon.entries {
        if n >= limit { break }
        for inf in SuffixEngine.inflections(forKey: entry.key, lexicon: lexicon, limit: 3) {
            emit(inf.cyrillic, inf.mongolian, "inflection")
            n += 1
            if n >= limit { break }
        }
    }
}


// --type: drive InputSession exactly as the keyboard does — a letter at a
// time, then Space to commit — and print what the host app would actually
// receive, plus the next-word predictions offered afterwards. Unit tests
// check pieces; this checks the path a user's thumbs take.
if wantType {
    while let line = readLine(strippingNewline: true) {
        let word = line.trimmingCharacters(in: .whitespaces)
        if word.isEmpty { continue }
        let session = InputSession()
        var host = ""
        func apply(_ cmds: [InputSession.Command]) {
            for c in cmds {
                switch c {
                case .insert(let s): host += s
                case .deleteBackward: if !host.isEmpty { host.removeLast() }
                }
            }
        }
        for ch in word { apply(session.insertLetter(String(ch))) }
        let shown = session.candidates.prefix(3)
            .map { $0.mongolian }.joined(separator: " | ")
        apply(session.space())
        let predicted = session.candidates.prefix(3)
            .map { $0.cyrillic ?? $0.mongolian }.joined(separator: ", ")
        let committed = host.trimmingCharacters(in: .whitespaces)
        print("\(word)\t\(committed)\t\(shown)\t\(predicted)")
    }
}

if !wantSpell && !wantInflect && !wantType {
    FileHandle.standardError.write(
        Data("usage: mongolgen [--spell] [--inflect] [--type] [--limit N]\n".utf8))
    exit(2)
}
