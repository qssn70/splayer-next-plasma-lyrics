// Verify the production QML XMLHttpRequest helper routes to the selected local port.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const qml = fs.readFileSync(__dirname + '/../contents/ui/PlayerBridge.qml', 'utf8');
const start = qml.indexOf('    function httpJson(');
const end = qml.indexOf('\n    function coverSource(', start);
assert.ok(start >= 0 && end > start);
const requests = [];
class FakeXHR {
    constructor() { this.readyState = 0; this.status = 200; this.responseText = '{}'; }
    open(method, url, asynchronous) { this.method=method; this.url=url; this.asynchronous=asynchronous; }
    setRequestHeader(name,value) { this.header=[name,value]; }
    send(body) {
        this.body=body;
        requests.push(this);
        this.responseText = this.url.endsWith('/lyric') ? '[00:01.000]歌词' :
            this.url.endsWith('/pause') ? 'OK' : '{"status":"playing"}';
        this.readyState = FakeXHR.DONE;
        this.onreadystatechange();
    }
}
FakeXHR.DONE=4;
const ctx = {XMLHttpRequest:FakeXHR, JSON, apiPort:14558, currentApiPort:23330};
vm.createContext(ctx);
vm.runInContext(qml.slice(start,end),ctx);
ctx.httpJson('GET','/status',null,(ok,result)=> {
    assert.equal(ok,true);
    assert.equal(result.status,'playing');
});
assert.equal(requests[0].url,'http://127.0.0.1:23330/status');
assert.equal(requests[0].asynchronous,true);
ctx.httpJson('GET','/lyric',null,(ok,result)=> {
    assert.equal(ok,true);
    assert.equal(result,'[00:01.000]歌词');
}, true);
ctx.currentApiPort=14558;
ctx.httpJson('POST','/api/seek',{positionMs:2000},(ok,result)=>{
    assert.equal(ok,true);
});
assert.equal(requests[2].url,'http://127.0.0.1:14558/api/seek');
assert.equal(requests[2].body,'{"positionMs":2000}');
assert.deepEqual(requests[2].header,['Content-Type','application/json']);
console.log('HTTP local routing: passed');
