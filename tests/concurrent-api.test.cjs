// Evaluate two actual QML bridge method sets in separate runtime contexts.
// The controls, playback positions and lyrics must not bleed between players.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const qml = fs.readFileSync(__dirname + '/../contents/ui/PlayerBridge.qml','utf8');
const methodNames=['numeric','coverSource','clearTrack','applyTrack','setClock','advanceClock',
    'applyLxStatus','pollState','fetchLyrics','onSocketMessage','sendControl',
    'resetConnection','deactivate'];
const methods = methodNames.map(name=>{
    const start = qml.indexOf('    function '+name+'(');
    assert.ok(start>=0,name+' missing');
    const next = qml.indexOf('\n    function ',start+10);
    const end = next<0 ? qml.indexOf('\n    onPlayerSourceChanged:',start) : next;
    assert.ok(end>start,name+' end missing');
    return qml.slice(start,end);
}).join('\n');
function library(name) {
    const src=fs.readFileSync(__dirname+'/../contents/ui/'+name+'.js','utf8').replace(/^\.pragma library\s*/m,'');
    const ctx={Number,String,Array,isFinite};
    vm.createContext(ctx);vm.runInContext(src,ctx);return ctx;
}
const Lyrics=library('Lyrics'),LxLyrics=library('LxLyrics');
let sState={track:{id:'song-a',title:'Song A',artists:[{name:'Singer A'}],duration:180000},
  position:1350,playing:true,speed:1,lyricOffsetMs:0,lyricAvailable:true,sendTimestamp:Date.now()};
let sLyrics={trackId:'song-a',lyricOffsetMs:0,lyric:[{startTime:1000,endTime:5000,words:[{word:'SPlayer lyrics',startTime:1000,endTime:5000}]}]};
let lState={status:'playing',name:'Song B',singer:'Singer B',albumName:'Album B',duration:250,progress:2.6,playbackRate:1,lyricLineText:'LX lyrics'};
let lLyrics={lyric:'[00:02.000]LX lyrics',tlyric:'[00:02.000]English',rlyric:'',lxlyric:''};
const requests=[];
function makeBridge(type) {
  const ctx={Date,Math,Array,Number,String,JSON,isFinite,encodeURIComponent,
    Lyrics,LxLyrics,bridgeEnabled:true,playerSource:type,apiPort:14558,lxApiPort:23330,
    apiConnected:false, trackId:'',songTitle:'',songArtist:'',coverUrl:'',lxLiveLyric:'',
    lyricLines:[],currentLineIndex:-1,currentTimeMs:0,durationMs:0,lyricOffsetMs:0,
    speed:1,isPlaying:false,anchorPosition:0,anchorAt:0,
    lastActiveMs:0,stateRequestPending:false,stateRequestStarted:0,stateRequestSerial:0,
    lyricRequestSerial:0,lyricRequestPending:false,lyricRequestStarted:0,lastLyricAttempt:0,
    apiGeneration:0,wsConnected:false,wsReconnectSuspended:false,
    resyncTimer:{restart(){}},reconnectTimer:{restart(){},stop(){}},
    httpJson(method,path,payload,callback,asText) {
      requests.push({type,method,path,payload});
      if(type==='splayer') {
        if(path==='/api/now-playing') return callback(true,structuredClone(sState));
        if(path==='/api/lyrics') return callback(true,structuredClone(sLyrics));
        return callback(true,{ok:true});
      }
      if(path.startsWith('/status?')) return callback(true,structuredClone(lState));
      if(path==='/lyric-all') return callback(true,structuredClone(lLyrics));
      return callback(true,asText?'OK':{ok:true});
    }
  };
  vm.createContext(ctx);vm.runInContext(methods,ctx);return ctx;
}
const s=makeBridge('splayer'),lx=makeBridge('lx');
s.pollState(true);lx.pollState(true);
assert.equal(s.songTitle,'Song A');assert.equal(lx.songTitle,'Song B');
assert.equal(s.lyricLines[0].text,'SPlayer lyrics');assert.equal(lx.lyricLines[0].text,'LX lyrics');
assert.equal(s.currentLineIndex,0);assert.equal(lx.currentLineIndex,0);
assert.equal(s.durationMs,180000);assert.equal(lx.durationMs,250000);
assert.equal(s.apiConnected,true);assert.equal(lx.apiConnected,true);
sState={...sState,track:{...sState.track,id:'song-c',title:'Song C'}};
sLyrics={trackId:'song-c',lyricOffsetMs:0,lyric:[{startTime:1000,endTime:5000,words:[{word:'New S lyrics',startTime:1000,endTime:5000}]}]};
s.onSocketMessage(JSON.stringify({kind:'event',type:'track',data:{track:sState.track}}));
assert.equal(s.lyricLines[0].text,'New S lyrics');
assert.equal(lx.lyricLines[0].text,'LX lyrics');
lState={...lState,status:'paused',progress:4.3};
lx.pollState(true);
assert.equal(lx.isPlaying,false);assert.equal(s.isPlaying,true);
assert.equal(s.lyricLines[0].text,'New S lyrics');
lx.deactivate();
assert.equal(lx.apiConnected,false);assert.equal(lx.lyricLines.length,0);
assert.equal(s.apiConnected,true);assert.equal(s.lyricLines[0].text,'New S lyrics');
assert.ok(requests.every(req => req.type==='splayer' ? req.path.startsWith('/api/') : !req.path.startsWith('/api/')));
console.log('Two independent API bridges: passed');
