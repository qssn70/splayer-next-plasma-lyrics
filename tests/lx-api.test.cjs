// Mock the LX Music Open API and exercise the same QML controller JS methods.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
function library(name) {
    const script = fs.readFileSync(__dirname + '/../contents/ui/' + name + '.js', 'utf8')
                     .replace(/^\.pragma library\s*/m, '');
    const ctx = {Array, Number, String, isFinite};
    vm.createContext(ctx);
    vm.runInContext(script, ctx);
    return ctx;
}
const Lyrics = library('Lyrics');
const LxLyrics = library('LxLyrics');
const qml = fs.readFileSync(__dirname + '/../contents/ui/PlayerBridge.qml', 'utf8');
const names = ['numeric','coverSource','clearTrack','applyTrack','setClock',
               'advanceClock','applyLxStatus','pollState','fetchLyrics',
               'onSocketMessage','sendControl','resetConnection'];
const methods = names.map(name => {
    const marker = '    function ' + name + '(';
    const start = qml.indexOf(marker);
    assert.ok(start >= 0, 'missing ' + name);
    const next = qml.indexOf('\n    function ', start + marker.length);
    const end = next >= 0 ? next : qml.indexOf('\n    onApiConnectedChanged:', start);
    assert.ok(end > start, 'cannot isolate ' + name);
    return qml.slice(start, end);
});
let status = {
    status:'playing', name:'测试歌', singer:'歌手', albumName:'专辑',
    duration:200, progress:1.1, playbackRate:1, picUrl:'https://example.test/cover.jpg',
    lyricLineText:'测试'
};
let allLyrics = {
    lyric:'[00:01.000]测试\n[00:04.000]第二句',
    tlyric:'[00:01.000]Test',
    rlyric:'[00:01.000]Romanization',
    lxlyric:'[00:01.000]<0,200>测<200,300>试\n[00:04.000]<0,300>第二句'
};
let allLyricsAvailable = true;
let online = true;
const calls = [];
const ctx = {
    Date, Math, Array, Number, String, JSON, isFinite, encodeURIComponent,
    Lyrics, LxLyrics, playerSource: 'lx', bridgeEnabled: true, lastActiveMs: 0, apiPort: 14558, lxApiPort: 23330,
    apiConnected: false, trackId:'', songTitle:'', songArtist:'', coverUrl:'',
    lxLiveLyric:'', lyricLines:[], currentLineIndex:-1, currentTimeMs:0,
    durationMs:0, lyricOffsetMs:0,speed:1, isPlaying:false,
    anchorPosition:0, anchorAt:0, stateRequestPending:false,
    stateRequestStarted:0, stateRequestSerial:0,lyricRequestSerial:0,
    lyricRequestPending:false,lyricRequestStarted:0,lastLyricAttempt:0,
    apiGeneration:0,wsConnected:false,wsReconnectSuspended:false,
    resyncTimer:{restart() {}}, reconnectTimer:{restart() {}},
    httpJson(method,path,payload,callback,asText) {
        calls.push({method,path,payload,asText});
        if (path.startsWith('/status?')) callback(online, online ? {...status} : null);
        else if (path === '/lyric-all') callback(allLyricsAvailable, allLyricsAvailable ? {...allLyrics} : null);
        else if (path === '/lyric') callback(true, '[00:01.000]Fallback');
        else callback(true, 'OK');
    }
};
vm.createContext(ctx);
vm.runInContext(methods.join('\n'),ctx);
ctx.pollState(true);
assert.equal(ctx.apiConnected,true);
assert.equal(ctx.songTitle,'测试歌');
assert.equal(ctx.songArtist,'歌手');
assert.equal(ctx.lyricLines.length,2);
assert.equal(ctx.lyricLines[0].words.length,2);
assert.equal(ctx.lyricLines[0].translatedLyric,'Test');
assert.equal(ctx.lyricLines[0].romanLyric,'Romanization');
assert.equal(ctx.lyricOffsetMs,0);
assert.equal(ctx.durationMs,200000); // LX returns seconds
assert.ok(ctx.currentTimeMs>=1100 && ctx.currentTimeMs<2500);
assert.equal(ctx.currentLineIndex,0);
assert.ok(calls.some(c=>c.method==='GET'&&c.path==='/lyric-all'));
ctx.sendControl('seek', 3700);
assert.equal(calls.at(-1).path, '/seek?offset=3.700');
assert.equal(calls.at(-1).method, 'GET');
assert.ok(ctx.currentTimeMs>=3700);
ctx.sendControl('next', 0);
assert.equal(calls.at(-1).path, '/skip-next');
ctx.sendControl('toggle', 0);
assert.equal(calls.at(-1).path, '/pause');
status = {...status, name:'新歌',progress:4.5};
allLyrics = {lyric:'[00:04.000]新歌词',tlyric:'',rlyric:'',lxlyric:''};
ctx.pollState(true);
assert.equal(ctx.songTitle,'新歌');
assert.equal(ctx.lyricLines[0].text,'新歌词');
allLyricsAvailable = false;
ctx.fetchLyrics(true);
assert.equal(ctx.lyricLines[0].text,'Fallback');
assert.ok(calls.some(c=>c.path === '/lyric'&&c.asText===true));
online = false;
ctx.pollState(true);
assert.equal(ctx.apiConnected,false);
assert.equal(ctx.isPlaying,false);
online = true;
ctx.pollState(true);
assert.equal(ctx.apiConnected,true);
assert.ok(calls.every(c=>!c.path.includes('lrclib') && !c.path.includes('music.163.com')));
assert.ok(!calls.some(c=>c.path==='/api/lyrics'));
console.log('LX Music API controller integration: passed');
