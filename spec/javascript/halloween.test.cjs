const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const source = readFileSync('app/javascript/controllers/halloween_controller.js', 'utf8').replace(/^import .*\n/gm, '').replace('export default class', 'return class')
function fixture(now, stored = null, attributes = { theme: 'os', accent: 'moss' }) {
  const values = new Map(Object.entries(attributes).map(([k, v]) => [`data-${k}`, v]))
  const root = { dataset: new Proxy({}, { set(_, k, v) { values.set(`data-${k}`, v); return true } }), getAttribute: k => values.get(k) ?? null, setAttribute: (k, v) => values.set(k, v), removeAttribute: k => values.delete(k) }
  const storage = new Map(stored ? [['trove-halloween-2026', stored]] : [])
  let timer = null
  const Controller = new Function('Controller', 'document', 'localStorage', 'Date', 'setTimeout', 'clearTimeout', source)(class {}, { documentElement: root, querySelector: () => ({ focus() {} }) }, { getItem: k => storage.get(k), setItem: (k, v) => storage.set(k, v) }, { now: () => now, UTC: Date.UTC }, fn => { timer = fn; return 1 }, () => {})
  const instance = Object.create(Controller.prototype)
  instance.element = { hidden: true }
  instance.invitationTarget = { hidden: false }; instance.noticeTarget = { hidden: true, querySelector: () => ({ focus() {} }) }; instance.messageTarget = {}
  return { instance, values, storage, expire: () => timer?.() }
}
test('display is opt-in, one campaign only, with exclusive UTC end boundary', () => {
  for (const date of ['2026-10-17T23:59:59Z', '2026-11-01T00:00:00Z', '2027-10-20T00:00:00Z']) {
    const { instance } = fixture(Date.parse(date)); instance.connect(); assert.equal(instance.element.hidden, true)
  }
  const { instance, values } = fixture(Date.parse('2026-10-31T23:59:59Z')); instance.connect()
  assert.equal(instance.element.hidden, false); assert.equal(values.get('data-theme'), 'os'); assert.equal(values.get('data-accent'), 'moss')
})
test('activation announces a reversible preview and Undo restores exact attributes', () => {
  for (const attributes of [{ theme: 'os', accent: 'moss' }, {}]) {
    const { instance, values, storage } = fixture(Date.parse('2026-10-20T12:00:00Z'), null, attributes)
    instance.connect(); instance.apply(); assert.equal(values.get('data-accent'), 'halloween'); assert.equal(instance.noticeTarget.hidden, false); assert.match(instance.messageTarget.textContent, /applied/)
    instance.undo(); assert.deepEqual(Object.fromEntries(values), Object.fromEntries(Object.entries(attributes).map(([k, v]) => [`data-${k}`, v]))); assert.equal(storage.get('trove-halloween-2026'), 'dismissed')
  }
})
test('dismissal persists and deadline restores a currently applied preview', () => {
  const dismissed = fixture(Date.parse('2026-10-20T12:00:00Z'), 'dismissed'); dismissed.instance.connect(); assert.equal(dismissed.instance.element.hidden, true)
  const { instance, expire, values } = fixture(Date.parse('2026-10-20T12:00:00Z')); instance.connect(); instance.apply(); expire(); assert.equal(instance.element.hidden, true); assert.equal(values.get('data-accent'), 'moss')
})
