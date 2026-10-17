const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = fs.readFileSync(__dirname + '/../contents/ui/LxLyrics.js', 'utf8')
    .replace(/^\.pragma library\s*/m, '');
const ctx = {Number, String, Array, isFinite};
vm.createContext(ctx);
vm.runInContext(source, ctx);

assert.equal(ctx.timestampMs('01', '02', '3'), 62300);
assert.equal(ctx.timestampMs('01', '02', '34'), 62340);
assert.equal(ctx.timestampMs('01', '02', '345'), 62345);
assert.equal(ctx.parseLrc('nonsense\n[ar:a]\n').length, 0);
const repeat = ctx.parseLrc('[offset:+150]\n[00:01.2][00:04.200]Hi');
assert.equal(repeat.length, 2);
assert.equal(repeat[0].startTime, 1350);
assert.equal(repeat[1].startTime, 4350);
assert.equal(repeat[0].text, 'Hi');
const karaoke = ctx.parseLxLyric('[00:01.000]<0,250>测<250,400>试');
assert.equal(karaoke.length, 1);
assert.equal(karaoke[0].text, '测试');
assert.equal(karaoke[0].words[0].startTime, 1000);
assert.equal(karaoke[0].words[1].endTime, 1650);
const all = ctx.fromApi({
    lyric: '[00:01.000]测试\n[00:03.000]下一句',
    lxlyric: '[00:01.000]<0,250>测<250,400>试\n[00:03.000]<0,300>下一句',
    tlyric: '[00:01.000]Test\n[00:03.000]Next',
    rlyric: '[00:01.000]Ce Shi'
});
assert.equal(all.length, 2);
assert.equal(all[0].words.length, 2);
assert.equal(all[0].translatedLyric, 'Test');
assert.equal(all[0].romanLyric, 'Ce Shi');
assert.equal(all[0].endTime, 3000);
assert.equal(all[1].endTime, all[1].startTime);
assert.equal(ctx.fromApi({lyric:'[00:01.000]Only LRC'})[0].text, 'Only LRC');
assert.equal(ctx.fromApi({lyric:'[ar:x]'}).length, 0);
assert.equal(ctx.fromApi(null).length, 0);
const lines = ctx.fromApi({lyric:'[00:01.000]One\n[00:01.300]Two', tlyric:'[00:01.320]二'});
assert.equal(lines[1].translatedLyric, '二');
assert.equal(lines[0].translatedLyric, '');
console.log('LX Music lyrics parsing: passed');
