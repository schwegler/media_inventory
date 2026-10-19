const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const source = readFileSync('app/javascript/controllers/halloween_controller.js', 'utf8').replace(/^import .*\n/gm, '').replace('export default class', 'return class')
const configSource = readFileSync('app/javascript/controllers/season_config.js', 'utf8').replace(/export /g, '')
const config = JSON.parse(readFileSync('config/seasonal.json', 'utf8'))
function fixture(instant = '2026-10-20T12:00:00Z', attributes = { theme: 'os', accent: 'moss' }) {
  let now = Date.parse(instant)
  const values = new Map(Object.entries(attributes).map(([k, v]) => [`data-${k}`, v]))
  const root = { dataset: new Proxy({}, { set(_, k, v) { values.set(`data-${k.replace(/[A-Z]/g, m => '-'+m.toLowerCase())}`, v); return true } }), getAttribute: k => values.get(k) ?? null, setAttribute: (k, v) => values.set(k, v), removeAttribute: k => values.delete(k) }
  const storage = new Map(), timers = [], events = []
  const adapter = { getItem: k => storage.get(k), setItem: (k, v) => storage.set(k, v), removeItem: k => storage.delete(k) }
  const body = { dataset: { viewerId: '1', uiPreferences: 'original' } }
  const document = { addEventListener() {}, removeEventListener() {}, documentElement: root, body, readyState: 'complete', querySelectorAll: () => [], querySelector: selector => selector === 'main' ? { focus() {} } : null }
  const window = { localStorage: adapter, sessionStorage: adapter, dispatchEvent: e => events.push(e), addEventListener() {}, removeEventListener() {} }
  const clock = { now: () => now, parse: Date.parse }
  const { availableSeason, currentSeason, SEASONAL_KEYS } = new Function('Date', configSource+';return {availableSeason, currentSeason, SEASONAL_KEYS}')(clock)
  const Controller = new Function('Controller', 'document', 'window', 'availableSeason', 'currentSeason', 'SEASONAL_KEYS', 'Date', 'CustomEvent', 'setTimeout', 'clearTimeout', 'innerWidth', 'innerHeight', source)(class {}, document, window, availableSeason, currentSeason, SEASONAL_KEYS, clock, class { constructor(name, options){ this.name=name;this.detail=options.detail } }, (fn, delay) => { timers.push({fn,delay}); return timers.length }, () => {}, 1000, 800)
  const instance = Object.create(Controller.prototype)
  instance.configValue = config; instance.stageTarget = { hidden: true, dataset: {} }; instance.hasStageTarget = true
  instance.invitationTarget = { hidden: true }; instance.noticeTarget = { hidden: true, querySelector: () => ({ focus() {} }) }; instance.messageTarget = {}; instance.pauseTargets = []; instance.atmosphereTargets = []
  return { instance, values, storage, body, document, timers, events, setTime: value => { now = Date.parse(value) }, original: Object.fromEntries(values) }
}
test('fresh display waits for one settled-page entrance and never activates a theme', () => {
  const f=fixture();f.instance.connect()
  assert.equal(f.instance.invitationTarget.hidden,true)
  assert.equal(f.timers.filter(t=>t.delay===1000).length,1)
  f.timers.find(t=>t.delay===1000).fn()
  assert.equal(f.instance.invitationTarget.hidden,false)
  assert.deepEqual(Object.fromEntries(f.values),f.original)
})
test('fixed date boundaries and disabled/unapproved Christmas art never invite or apply', () => {
  for(const instant of ['2026-10-17T23:59:59Z','2026-11-01T00:00:00Z','2027-10-20T00:00:00Z']){
    const f=fixture(instant);f.instance.connect();assert.equal(f.instance.stageTarget.hidden,true);assert.equal(f.timers.length,0)
  }
  const f=fixture('2026-10-31T23:59:59Z');f.instance.connect();f.instance.apply();assert.equal(f.values.get('data-accent'),'halloween')
})
test('activation, pause and atmosphere controls undo every changed attribute exactly', () => {
  for(const attributes of [{theme:'os',accent:'moss'},{}]){
    const f=fixture(undefined,attributes);f.instance.connect();f.instance.apply()
    assert.equal(f.values.get('data-theme'),'dark');assert.equal(f.values.get('data-season'),'halloween')
    f.instance.pause();assert.equal(f.values.get('data-season-motion'),'paused')
    f.instance.atmosphere();assert.equal(f.values.get('data-season-effects'),'off')
    f.instance.undo();assert.deepEqual(Object.fromEntries(f.values),f.original)
    assert.equal(f.storage.get('seasonal-theme:v1'),'off');assert.equal(f.events.at(-1).detail.active,false)
  }
})
test('choice survives navigation, while viewer and saved-preference changes take priority', () => {
  const f=fixture();f.instance.connect();f.instance.apply();f.instance.reset();f.instance.connect()
  assert.equal(f.values.get('data-season'),'halloween')
  f.instance.reset();f.body.dataset.uiPreferences='new';f.values.set('data-theme','dark');f.values.set('data-accent','ink');f.instance.connect()
  assert.equal(f.values.get('data-accent'),'ink');assert.equal(f.storage.get('seasonal-theme:v1'),'off')
  const g=fixture();g.instance.connect();g.instance.apply();g.instance.reset();g.body.dataset.viewerId='2';g.instance.connect()
  assert.deepEqual(Object.fromEntries(g.values),g.original)
})
test('X dismissal is per-tab, footer reset reopens, and the promotion deadline hides the character while preserving explicit appearance', () => {
  const f=fixture();f.instance.connect();f.instance.dismiss();f.instance.connect();assert.equal(f.instance.stageTarget.hidden,true)
  f.instance.resetChoice();assert.equal(f.instance.invitationTarget.hidden,false)
  f.instance.apply();f.setTime('2026-11-01T00:00:00Z');f.timers.find(t=>t.delay>1000).fn()
  assert.equal(f.values.get('data-season'),'halloween');assert.equal(f.instance.stageTarget.hidden,true)
})

test('crowded viewport defers the overlay instead of covering protected controls', () => {
 const f=fixture();f.instance.connect()
 Object.assign(f.instance.stageTarget,{style:{},offsetWidth:176,offsetHeight:170,getBoundingClientRect:()=>({}),contains:()=>false})
 f.document.querySelectorAll=()=>[{getBoundingClientRect:()=>({left:0,top:0,right:1000,bottom:800,width:1000,height:800})}]
 f.instance.position();assert.equal(f.instance.stageTarget.style.visibility,'hidden')
 f.document.querySelectorAll=()=>[]
 f.instance.position();assert.equal(f.instance.stageTarget.style.visibility,'visible')
})


test('saved settings apply after a Turbo morph without reconnecting or revealing the mascot',()=>{
 const f=fixture();f.instance.connect()
 f.body.dataset.uiPreferences=JSON.stringify({theme:'os',accent:'moss',seasonalTheme:'halloween'})
 f.instance.refresh();assert.equal(f.values.get('data-season'),'halloween');assert.equal(f.instance.stageTarget.hidden,true)
 f.values.set('data-theme','os');f.values.set('data-accent','moss');f.instance.refresh();assert.equal(f.values.get('data-theme'),'dark')
 f.instance.reset();f.instance.refresh();assert.equal(f.values.get('data-theme'),'dark')
 f.body.dataset.uiPreferences=JSON.stringify({theme:'light',accent:'ink',seasonalTheme:'off'})
 f.instance.refresh();assert.equal(f.values.get('data-theme'),'light');assert.equal(f.values.has('data-season'),false)
 const g=fixture();g.body.dataset.uiPreferences=JSON.stringify({theme:'os',accent:'moss',seasonalTheme:'off'})
 g.instance.connect();g.instance.apply();g.body.dataset.viewerId='2';g.instance.refresh();assert.equal(g.values.has('data-season'),false)
})


test('an explicit pre-preset browser choice survives the added default field when base preferences match',()=>{
 const f=fixture();f.body.dataset.uiPreferences=JSON.stringify({theme:'os',accent:'moss'})
 f.instance.connect();f.instance.apply();f.instance.reset()
 f.body.dataset.uiPreferences=JSON.stringify({seasonalTheme:'off',theme:'os',accent:'moss'})
 f.instance.connect();assert.equal(f.values.get('data-season'),'halloween')
 f.instance.undo();assert.deepEqual(Object.fromEntries(f.values),f.original)
})
