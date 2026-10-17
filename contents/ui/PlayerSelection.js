.pragma library

// Pure function: no shared runtime state, deterministic under simultaneous polling.
function choose(mode, manual, splayer, lx) {
    var s = !!splayer.connected
    var l = !!lx.connected
    if (mode === "manual") {
        return {splayer: manual === "splayer" && s,
                lx: manual === "lx" && l, dual: false}
    }
    var sp = s && !!splayer.playing
    var lp = l && !!lx.playing
    if (sp && lp) return {splayer: true, lx: true, dual: true}
    if (sp) return {splayer: true, lx: false, dual: false}
    if (lp) return {splayer: false, lx: true, dual: false}
    if (!s && !l) return {splayer: false, lx: false, dual: false}
    if (!s) return {splayer: false, lx: true, dual: false}
    if (!l) return {splayer: true, lx: false, dual: false}
    if (splayer.hasTrack && !lx.hasTrack) return {splayer: true, lx: false, dual: false}
    if (lx.hasTrack && !splayer.hasTrack) return {splayer: false, lx: true, dual: false}
    // Timestamps are set when playback starts or a playing track changes.
    // Equal/unknown timestamps fall back to SPlayer for stable initial display.
    if ((lx.lastActiveMs || 0) > (splayer.lastActiveMs || 0)) {
        return {splayer: false, lx: true, dual: false}
    }
    return {splayer: true, lx: false, dual: false}
}
