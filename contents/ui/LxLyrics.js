.pragma library

// Convert LX Music's local /lyric-all response to the LyricLine-like structure
// used by SPlayer-Next. No external lyrics lookup is performed.
function finiteNumber(value, fallback) {
    var valueNumber = Number(value)
    return isFinite(valueNumber) ? valueNumber : fallback
}

function timestampMs(minutes, seconds, fraction) {
    // LRC fractions represent tenths / hundredths / thousandths of a second.
    var decimals = String(fraction || "")
    var millis = decimals ? Number((decimals + "000").slice(0, 3)) : 0
    return (Number(minutes) * 60 + Number(seconds)) * 1000 + millis
}

function headerOffset(text) {
    var matched = /^\s*\[offset:\s*([+-]?\d+)\s*\]/im.exec(text)
    return matched ? finiteNumber(matched[1], 0) : 0
}

function parseLrc(text) {
    if (typeof text !== "string" || !text.length) return []
    var offset = headerOffset(text)
    var rows = text.replace(/^\uFEFF/, "").split(/\r?\n/)
    var result = []
    for (var i = 0; i < rows.length; i++) {
        var row = rows[i]
        var tag = /\[(\d{1,3}):([0-5]?\d)(?:[.:](\d{1,3}))?\]/g
        var matches = []
        var match
        while ((match = tag.exec(row)) !== null) {
            matches.push({at: timestampMs(match[1], match[2], match[3]) + offset, end: tag.lastIndex})
        }
        if (!matches.length) continue // metadata and untimed text
        // Allow multiple timestamps for a repeated chorus.
        var body = row.slice(matches[matches.length - 1].end).trim()
        if (!body) continue
        for (var j = 0; j < matches.length; j++) {
            result.push({startTime: Math.max(0, matches[j].at), endTime: 0,
                         text: body, words: [], translatedLyric: "", romanLyric: ""})
        }
    }
    result.sort(function(a, b) { return a.startTime - b.startTime })
    return result
}

// LX extended lyrics (lxlyric) use <relativeStartMs,durationMs>word chunks:
// [00:01.000]<0,250>Hello <250,400>world
function parseLxLyric(text) {
    if (typeof text !== "string" || !text.length) return []
    var offset = headerOffset(text)
    var result = []
    var rows = text.replace(/^\uFEFF/, "").split(/\r?\n/)
    for (var i = 0; i < rows.length; i++) {
        var row = rows[i]
        var tag = /\[(\d{1,3}):([0-5]?\d)(?:[.:](\d{1,3}))?\]/g
        var matches = [], found
        while ((found = tag.exec(row)) !== null) {
            matches.push({at: Math.max(0, timestampMs(found[1], found[2], found[3]) + offset), end: tag.lastIndex})
        }
        if (!matches.length) continue
        var body = row.slice(matches[matches.length - 1].end)
        var wordTag = /<(\d+),(\d+)>/g
        var pieces = [], token
        while ((token = wordTag.exec(body)) !== null) {
            pieces.push({start: finiteNumber(token[1], 0), duration: finiteNumber(token[2], 0),
                         from: wordTag.lastIndex, to: token.index})
        }
        if (!pieces.length) continue
        for (var j = 0; j < matches.length; j++) {
            var start = matches[j].at, words = [], plain = ""
            for (var k = 0; k < pieces.length; k++) {
                var piece = pieces[k]
                var next = k + 1 < pieces.length ? pieces[k + 1].to : body.length
                var value = body.slice(piece.from, next)
                if (!value) continue
                var wordStart = start + piece.start
                words.push({word: value, startTime: wordStart,
                            endTime: wordStart + Math.max(0, piece.duration)})
                plain += value
            }
            if (plain) result.push({startTime: start, endTime: 0, text: plain,
                                    words: words, translatedLyric: "", romanLyric: ""})
        }
    }
    result.sort(function(a, b) { return a.startTime - b.startTime })
    return result
}

function mergeTranslations(lines, extraLines, key) {
    // Global closest-time matching avoids an earlier line consuming the next
    // line's translation when their timestamps are close together.
    var pairs = []
    for (var i = 0; i < lines.length; i++) {
        for (var j = 0; j < extraLines.length; j++) {
            var distance = Math.abs(lines[i].startTime - extraLines[j].startTime)
            if (distance <= 650) pairs.push({line: i, extra: j, distance: distance})
        }
    }
    pairs.sort(function(a, b) { return a.distance - b.distance })
    var usedLine = [], usedExtra = []
    for (var k = 0; k < pairs.length; k++) {
        var pair = pairs[k]
        if (usedLine[pair.line] || usedExtra[pair.extra]) continue
        lines[pair.line][key] = extraLines[pair.extra].text
        usedLine[pair.line] = true
        usedExtra[pair.extra] = true
    }
}

function fromApi(reply) {
    if (!reply || typeof reply !== "object") return []
    var normal = parseLrc(reply.lyric)
    var karaoke = parseLxLyric(reply.lxlyric)
    // Prefer the player's actual extended word timestamps if available.
    var lines = karaoke.length ? karaoke : normal
    if (!lines.length) return []
    mergeTranslations(lines, parseLrc(reply.tlyric), "translatedLyric")
    mergeTranslations(lines, parseLrc(reply.rlyric), "romanLyric")
    for (var i = 0; i < lines.length; i++) {
        // Keep a lyric visible through the inter-line pause, until the next line.
        // The final line has an open end, like a normal un-timed LRC line.
        lines[i].endTime = i + 1 < lines.length ? Math.max(lines[i].startTime,
                                              lines[i + 1].startTime) : lines[i].startTime
    }
    return lines
}
