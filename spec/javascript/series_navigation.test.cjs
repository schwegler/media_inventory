const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')

function setup() {
  const timers = new Map()
  let nextTimer = 0, submissions = 0
  const select = { value: '1' }
  const source = fs.readFileSync('app/javascript/controllers/series_navigation_controller.js', 'utf8')
    .replace(/^import .*\n/gm, '').replace('export default class', 'return class')
  const Class = new Function('Controller', 'setTimeout', 'clearTimeout', source)(class { dispatch() {} },
    callback => { timers.set(++nextTimer, callback); return nextTimer }, id => timers.delete(id))
  const controller = new Class()
  controller.element = { requestSubmit() { submissions++ }, querySelector() { return select } }
  return { controller, select, submissions: () => submissions, tick() {
    const callbacks = [...timers.values()]; timers.clear(); callbacks.forEach(callback => callback())
  } }
}

test('applying filters during a pending search does not submit a stale second request', () => {
  const state = setup()
  state.controller.search()
  state.controller.start({ submitter: null })
  state.tick()
  assert.equal(state.submissions(), 0)
})

test('changing status submits once and cancels the pending query debounce', () => {
  const state = setup()
  state.controller.search()
  state.controller.submit()
  state.tick()
  assert.equal(state.submissions(), 1)
})

test('season navigation keeps the requested season and cancels a pending search', () => {
  const state = setup()
  state.controller.search()
  state.controller.start({ submitter: { name: 'season', value: '3' } })
  state.tick()
  assert.equal(state.select.value, '3')
  assert.equal(state.submissions(), 0)
})

test('disconnecting a replaced filter form prevents any late search request', () => {
  const state = setup()
  state.controller.search()
  state.controller.disconnect()
  state.tick()
  assert.equal(state.submissions(), 0)
})
