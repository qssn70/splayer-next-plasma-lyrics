const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const root = __dirname + '/../contents/ui/';
const compact = fs.readFileSync(root + 'CompactRepresentation.qml', 'utf8');
const main = fs.readFileSync(root + 'main.qml', 'utf8');
const bridge = fs.readFileSync(root + 'PlayerBridge.qml', 'utf8');
const helper = fs.readFileSync(root + 'Lyrics.js', 'utf8').replace(/^\.pragma library\s*/m, '');
const m = compact.match(/^    function htmlHex\(colorValue\) \{[\s\S]*?^    \}/m);
assert.ok(m);
const ctx = {Math};
vm.createContext(ctx);
vm.runInContext(m[0], ctx);
assert.equal(ctx.htmlHex({r: 1, g: 1, b: 1}), '#ffffff');
assert.equal(ctx.htmlHex({r: 0, g: 0, b: 0}), '#000000');
assert.equal(ctx.htmlHex({r: 0.5, g: 0.25, b: 1}), '#8040ff');
assert.equal(ctx.htmlHex({r: -0.5, g: 1.5, b: 0}), '#00ff00');
const words = {words: [
  {word: '山', startTime: 1000, endTime: 1600},
  {word: '河', startTime: 1600, endTime: 2200}
], translatedLyric: 'Mountains and rivers'};
const lyrics = {Array, Number, String, isFinite};
vm.createContext(lyrics); vm.runInContext(helper, lyrics);
const darkForeground = ctx.htmlHex({r: .95, g: .95, b: .95});
const lightForeground = ctx.htmlHex({r: .08, g: .08, b: .08});
const highlight = ctx.htmlHex({r: .3, g: .6, b: 1});
const dark = lyrics.karaokeMarkup(words, 1200, 'bilingual', highlight, darkForeground);
const light = lyrics.karaokeMarkup(words, 1200, 'bilingual', highlight, lightForeground);
assert.ok(dark.includes('color:' + darkForeground));
assert.ok(light.includes('color:' + lightForeground));
assert.ok(dark.includes('color:' + highlight));
assert.notEqual(dark, light);
assert.ok(compact.includes('htmlHex(resolvedHighlightColor), htmlHex(resolvedTextColor)'));
assert.ok(compact.includes('color: compactRoot.resolvedTextColor'));
assert.equal(main.match(/lyricLine: (splayer|lxmusic)\.currentLineIndex/g).length, 2);
assert.ok(!main.includes('karaokeMarkup:'));
assert.ok(!bridge.includes('Kirigami.Theme.textColor'));
assert.ok(!bridge.includes('Kirigami.Theme.highlightColor'));
console.log('Panel light/dark karaoke color regression: passed');
