const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const source=readFileSync('app/javascript/controllers/appearance_menu_controller.js','utf8').replace(/^import .*\n/gm,'').replace('export default class','return class')
function fixture(saved,viewer='guest',preferences={theme:'os',accent:'moss'}) {
 const storage=new Map(),events=[]
 const key=`trove-appearance:v1:${viewer}`
 if(saved)storage.set(key,JSON.stringify(saved))
 const document={body:{dataset:{viewerId:viewer,uiPreferences:JSON.stringify(preferences)}},documentElement:{dataset:{...preferences}},dispatchEvent:e=>events.push(e)}
 const localStorage={getItem:k=>storage.get(k),setItem:(k,v)=>storage.set(k,v)}
 const C=new Function('Controller','document','localStorage','CustomEvent',source)(class{},document,localStorage,class{constructor(type){this.type=type}})
 const instance=new C();instance.modeTargets=[];instance.accentTargets=[];instance.feedbackTarget={}
 return {instance,storage,document,events,key}
}
test('browser appearance survives navigation for its viewer without writing shelf presentation',()=>{
 const f=fixture();f.storage.set('trove-shelf-theme','electric');f.instance.connect();f.instance.change({target:{name:'base-mode',value:'light'}})
 assert.equal(f.document.documentElement.dataset.theme,'light');assert.equal(f.storage.get('trove-shelf-theme'),'electric')
 assert.equal(f.events[0].type,'trove:base-appearance')
 f.document.documentElement.dataset.theme='os';f.instance.connect();assert.equal(f.document.documentElement.dataset.theme,'light')
})
test('saved account preferences supersede stale browser choices and viewer identities stay separate',()=>{
 const f=fixture({mode:'dark',accent:'ink',preferences:'old'},'123');f.instance.connect()
 assert.equal(f.document.documentElement.dataset.theme,'os');assert.equal(f.document.documentElement.dataset.accent,'moss')
 f.instance.change({target:{name:'base-mode',value:'dark'}})
 assert.ok(f.storage.has('trove-appearance:v1:123'));assert.equal(f.storage.has('trove-appearance:v1:guest'),false)
})
test('restored seasonal styling wins until an explicit base choice turns it off',()=>{
 const f=fixture();f.document.documentElement.dataset.season='halloween';f.document.documentElement.dataset.theme='dark';f.instance.connect()
 assert.equal(f.document.documentElement.dataset.theme,'dark')
 f.instance.change({target:{name:'base-mode',value:'unsupported'}});assert.equal(f.events.length,0)
})
