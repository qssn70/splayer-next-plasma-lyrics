// Lightweight integration test for the QML JavaScript controller, without Qt GUI.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const qml = fs.readFileSync(__dirname + '/../contents/ui/PlayerBridge.qml', 'utf8');
const logic = fs.readFileSync(__dirname + '/../contents/ui/Lyrics.js', 'utf8').replace(/^\.pragma library\s*/m, '');
const lyricContext = {Array, Number, String, isFinite};
vm.createContext(lyricContext);
vm.runInContext(logic, lyricContext);
const names = ['numeric','coverSource','clearTrack','applyTrack','setClock','advanceClock','pollState','fetchLyrics','onSocketMessage','sendControl'];
const extracts = names.map(name => {
    const marker = '    function ' + name + '(';
    const start = qml.indexOf(marker);
    assert.ok(start >= 0, 'missing ' + name);
    const next = qml.indexOf('\n    function ', start + marker.length);
    const end = next >= 0 ? next : qml.indexOf('\n    onApiPortChanged:', start);
    assert.ok(end > start, 'cannot isolate function ' + name);
    return qml.slice(start, end);
});
let state = {
    track: {id: 'one', title: '第一首', artists: [{name:'歌手'}], duration: 5000},
    position: 900, playing: true, speed: 1, sendTimestamp: Date.now(),
    lyricAvailable: true, lyricOffsetMs: 50
};
let lyrics = {trackId:'one', lyricOffsetMs: 50, lyric:[
    {startTime: 1000, endTime: 2600, words:[{word:'你好',startTime:1000,endTime:2200}], translatedLyric:'hello'}
]};
const requests = [];
const ctx = {
    Lyrics: lyricContext, Date, Math, Array, Number, String, isFinite,
    playerSource: 'splayer', bridgeEnabled: true, lastActiveMs: 0,
    trackId:'', songTitle:'',songArtist:'',coverUrl:'', lyricLines:[],
    currentLineIndex:-1, currentTimeMs:0,durationMs:0,lyricOffsetMs:0,
    speed:1,isPlaying:false,anchorPosition:0,anchorAt:0,
    stateRequestPending:false,stateRequestStarted:0,stateRequestSerial:0,
    lyricRequestSerial:0,lyricRequestPending:false,lyricRequestStarted:0,lastLyricAttempt:0,
    apiGeneration:0, apiConnected:false,
    resyncTimer: {restart() {}},
    httpJson(method,path,payload,callback){
        requests.push({method,path,payload});
        if(path==='/api/now-playing') callback(true,structuredClone(state));
        else if(path==='/api/lyrics') callback(true,structuredClone(lyrics));
        else if(method==='POST') callback(true,{ok:true});
        else callback(false,null);
    }
};
vm.createContext(ctx);
vm.runInContext(extracts.join('\n'),ctx);
ctx.pollState(true);
assert.equal(ctx.apiConnected,true);
assert.equal(ctx.trackId,'one');
assert.equal(ctx.songTitle,'第一首');
assert.equal(ctx.lyricLines.length,1);
assert.equal(ctx.songArtist,'歌手');
assert.ok(ctx.currentTimeMs>=900);
assert.equal(ctx.lyricOffsetMs,50);
assert.equal(ctx.currentLineIndex,-1); // position 900+50 before first line
// Seek: the API accepts a POST with milliseconds.
ctx.sendControl('seek',2300);
assert.equal(requests.at(-1).payload.positionMs,2300);
assert.equal(ctx.currentLineIndex,0);
// A new song event invalidates old lyrics and fetches fresh lyrics by API.
state={...state,track:{id:'two',title:'第二首',artists:[{name:'新歌手'}],duration:6000},position:1200};
lyrics={trackId:'two',lyricOffsetMs:0,lyric:[
    {startTime:1000,endTime:4000,words:[{word:'第二首歌词',startTime:1000,endTime:4000}]}
]};
ctx.onSocketMessage(JSON.stringify({kind:'event',type:'track',data:{track:state.track}}));
assert.equal(ctx.trackId,'two');
assert.equal(ctx.lyricLines[0].text,'第二首歌词');
// Source still never queries a remote lyrics service.
assert.ok(requests.every(r=>r.path.startsWith('/api/')));
assert.ok(requests.some(r=>r.path==='/api/lyrics'));
console.log('API controller integration: passed');
