.pragma library

// SPlayer-Next LyricLine -> compact QML-friendly objects. All timestamps are ms.
function finiteNumber(value, fallback) {
    var n = Number(value)
    return isFinite(n) ? n : fallback
}

function normalizeLines(raw) {
    if (!Array.isArray(raw)) return []
    var result = []
    for (var i = 0; i < raw.length; i++) {
        var line = raw[i]
        if (!line || typeof line !== "object") continue
        var start = finiteNumber(line.startTime, -1)
        if (start < 0) continue
        var words = []
        if (Array.isArray(line.words)) {
            for (var j = 0; j < line.words.length; j++) {
                var word = line.words[j]
                if (!word || typeof word !== "object") continue
                words.push({
                    word: String(word.word === undefined ? "" : word.word),
                    startTime: finiteNumber(word.startTime, start),
                    endTime: finiteNumber(word.endTime, start)
                })
            }
        }
        var plain = ""
        for (var k = 0; k < words.length; k++) plain += words[k].word
        if (!words.length && typeof line.text === "string") plain = line.text
        if (!words.length && typeof line.content === "string") plain = line.content
        var end = finiteNumber(line.endTime, start)
        result.push({
            startTime: start,
            endTime: end,
            text: plain,
            words: words,
            translatedLyric: typeof line.translatedLyric === "string" ? line.translatedLyric : "",
            romanLyric: typeof line.romanLyric === "string" ? line.romanLyric : "",
            isBG: !!line.isBG,
            isDuet: !!line.isDuet
        })
    }
    result.sort(function(a, b) { return a.startTime - b.startTime })
    return result
}

function currentIndex(lines, timeMs) {
    if (!lines || !lines.length || !isFinite(timeMs)) return -1
    var low = 0
    var high = lines.length - 1
    var found = -1
    while (low <= high) {
        var mid = (low + high) >> 1
        if (lines[mid].startTime <= timeMs) {
            found = mid
            low = mid + 1
        } else {
            high = mid - 1
        }
    }
    if (found < 0) return -1
    // A lyric's known end time prevents showing it through a long instrumental gap.
    // Ignore invalid/zero-length end timestamps (some plain LRC parsers emit them).
    var line = lines[found]
    if (line.endTime > line.startTime + 100 && timeMs >= line.endTime) return -1
    return found
}

function displayText(line, mode) {
    if (!line) return ""
    var original = line.text || ""
    var translated = line.translatedLyric || ""
    var romanized = line.romanLyric || ""
    if (mode === "translation") return translated || original
    if (mode === "romanization") return romanized || original
    if (mode === "bilingual") return original + (translated ? " · " + translated : "")
    return original
}

function escapeHtml(s) {
    return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;")
        .replace(/>/g, "&gt;").replace(/"/g, "&quot;")
        .replace(/ /g, "&nbsp;").replace(/\n/g, " ")
}

// Return a single-line rich-text string. Empty means to render the plain text.
// SPlayer's words[] has genuine per-word times for YRC/KRC/TTML, unlike plain LRC.
function karaokeMarkup(line, timeMs, mode, activeColor, inactiveColor) {
    if (!line || !line.words || line.words.length < 2) return ""
    if (mode === "translation" || mode === "romanization") return ""
    var output = ""
    for (var i = 0; i < line.words.length; i++) {
        var word = line.words[i]
        var active = timeMs >= word.startTime
        var chosenColor = active ? activeColor : inactiveColor
        output += '<span style="color:' + chosenColor + ';">' + escapeHtml(word.word) + '</span>'
    }
    if (mode === "bilingual" && line.translatedLyric)
        output += '<span style="color:' + inactiveColor + ';"> · ' + escapeHtml(line.translatedLyric) + '</span>'
    return output
}
