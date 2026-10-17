const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')

function setup({ explicit = true, state = 'refreshing', saved = null } = {}) {
  const timers = [], visits = [], storage = new Map()
  const status = { textContent: '', focus() {} }
  const panel = { dataset: { refreshUrl: '/metadata/tv_shows/1/status', refreshResult: String(explicit), refreshState: state },
    querySelector: () => status, scrollIntoView() {} }
  if (saved) storage.set('trove:metadata:/metadata/tv_shows/1/status', JSON.stringify(saved))
  const sessionStorage = { getItem: key => storage.get(key) || null, setItem: (key, value) => storage.set(key, value), removeItem: key => storage.delete(key) }
  let response = { ok: true, redirected: false, json: async () => ({ state: 'refreshing', message: 'Checking', request_id: 'request-1' }) }
  let calls = 0, signal
  const fetch = async (url, options) => { calls++; signal = options.signal; return response }
  const source = fs.readFileSync('app/javascript/controllers/refresh_controller.js', 'utf8').replace(/^import .*\n/gm, '').replace('export default class', 'return class')
  const Class = new Function('Controller', 'Turbo', 'sessionStorage', 'fetch', 'window', 'setTimeout', 'clearTimeout', source)(
    class {}, { visit: (...args) => visits.push(args) }, sessionStorage, fetch, { location: { href: '/tv_shows/1' } },
    callback => { timers.push(callback); return timers.length }, () => {})
  const controller = new Class()
  controller.element = { closest: () => panel, setAttribute() {}, removeAttribute() {} }
  controller.connect()
  return { controller, timers, visits, status, storage, setResponse: value => { response = value }, calls: () => calls, signal: () => signal }
}

test('ordinary visits do not poll; explicit refresh uses status JSON and one terminal page update', async () => {
  const ordinary = setup({ explicit: false })
  assert.equal(ordinary.timers.length, 0)
  const s = setup()
  assert.equal(s.timers.length, 1)
  await s.controller.poll()
  assert.equal(s.calls(), 1)
  assert.equal(s.visits.length, 0)
  assert.equal(s.controller.pending.requestId, 'request-1')
  s.setResponse({ ok: true, json: async () => ({ state: 'success', message: 'Done' }) })
  await s.controller.poll()
  assert.equal(s.visits.length, 1)
  assert.equal(s.storage.size, 0)
  await s.controller.poll()
  assert.equal(s.visits.length, 1)
})

test('reconnect retains the retry bound and stops after ten checks', () => {
  const s = setup({ explicit: false, saved: { startedAt: Date.now(), count: 10 } })
  assert.equal(s.timers.length, 0)
  assert.match(s.status.textContent, /taking longer/)
  assert.equal(s.storage.size, 0)
})

test('authorization failure stops without navigation and disconnect aborts outstanding work', async () => {
  const s = setup()
  s.setResponse({ ok: false, status: 403 })
  await s.controller.poll()
  assert.equal(s.controller.pending, null)
  assert.equal(s.visits.length, 0)
  assert.match(s.status.textContent, /Unable to check/)
  const active = setup()
  await active.controller.poll()
  active.controller.disconnect()
  assert.equal(active.signal().aborted, true)
  const before = active.calls()
  await active.controller.poll()
  assert.equal(active.calls(), before)
})
