const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const script = fs.readFileSync(__dirname + '/../contents/ui/Lyrics.js', 'utf8').replace(/^\.pragma library\s*/m, '');
const ctx = {Array, Number, String, isFinite};
vm.createContext(ctx);
vm.runInContext(script, ctx);
const lines = ctx.normalizeLines([
    {startTime: 1000, endTime: 2200, words: [{word: 'Hello ', startTime:1000, endTime:1400}, {word:'世界',startTime:1400,endTime:2200}], translatedLyric:'你好 世界', romanLyric:'ni hao'},
    {startTime: 4000, endTime: 6000, words: [{word:'next',startTime:4000,endTime:6000}]}
]);
assert.equal(lines.length,2);
assert.equal(lines[0].text,'Hello 世界');
assert.equal(ctx.currentIndex(lines,999),-1);
assert.equal(ctx.currentIndex(lines,1700),0);
assert.equal(ctx.currentIndex(lines,3000),-1); // instrumental pause
assert.equal(ctx.currentIndex(lines,4200),1);
assert.equal(ctx.displayText(lines[0],'original'),'Hello 世界');
assert.equal(ctx.displayText(lines[0],'translation'),'你好 世界');
assert.equal(ctx.displayText(lines[0],'romanization'),'ni hao');
assert.equal(ctx.displayText(lines[0],'bilingual'),'Hello 世界 · 你好 世界');
const rich = ctx.karaokeMarkup(lines[0], 1200,'original','#f00','#ccc');
assert.ok(rich.includes('color:#f00'));
assert.ok(rich.includes('color:#ccc'));
assert.equal(ctx.karaokeMarkup(lines[1],4200,'original','#f00','#ccc'),'');
assert.equal(ctx.escapeHtml('<&"'), '&lt;&amp;&quot;');
const empty = ctx.normalizeLines(null);
assert.equal(empty.length,0);
console.log('Lyrics.js: 14 assertions passed');
