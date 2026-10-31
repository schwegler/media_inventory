const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')

function setup() {
  const listeners = new Map(), tasks = []
  const document = { addEventListener: (name, handler) => listeners.set(name, handler), removeEventListener: name => listeners.delete(name) }
  const frame = { src: '', reload() { this.reloaded = true }, contains: () => true }
  const root = { dataset: {}, isConnected: true, querySelector: () => frame, addEventListener() {}, removeEventListener() {} }
  const source = fs.readFileSync('app/javascript/controllers/series_response_controller.js', 'utf8')
    .replace(/^import .*\n/gm, '').replace('export default class', 'return class')
  const Class = new Function('Controller', 'document', 'window', 'crypto', 'queueMicrotask', 'FormData', source)(class {}, document,
    { location: { href: 'https://trove.example/tv_shows/1?season=0' } }, { randomUUID: () => 'owner' }, task => tasks.push(task), class { constructor(form) { return form.entries } })
  const controller = new Class(); controller.element = root; controller.connect()
  return { controller, frame, root, listeners, flush() { tasks.splice(0).forEach(task => task()) } }
}

function request(state, method, url) {
  const form = { matches: () => true }
  const event = { target: form, detail: { url, fetchOptions: { method, headers: {} } } }
  state.controller.request(event)
  return event.detail.fetchOptions.headers['X-Series-Request']
}

function response(state, token, refresh = false, succeeded = true) {
  let prevented = false
  state.controller.response({ preventDefault() { prevented = true }, detail: { fetchResponse: {
    succeeded, header(name) { return name === 'X-Series-Request' ? token : refresh ? 'true' : null }
  } } })
  return prevented
}

test('a late tracking write refreshes the latest selected season instead of its submitted season', () => {
  const state = setup()
  const mutation = request(state, 'POST', 'https://trove.example/tv_episodes/9/toggle_watched')
  const navigation = request(state, 'GET', 'https://trove.example/tv_shows/1?season=1')
  assert.equal(response(state, navigation), false)
  response(state, mutation, true)
  state.flush()
  assert.equal(state.frame.src, 'https://trove.example/tv_shows/1?season=1')
})

test('obsolete reads cannot update the frame or history after a newer navigation', () => {
  const state = setup()
  const old = request(state, 'GET', 'https://trove.example/tv_shows/1?season=0')
  const latest = request(state, 'GET', 'https://trove.example/tv_shows/1?season=1')
  assert.equal(response(state, old), true)
  assert.equal(response(state, latest), false)
  const event = { target: state.frame, detail: { newFrame: { dataset: { seriesRequestToken: old } }, render: () => 'old content' } }
  state.controller.render(event)
  assert.equal(event.detail.render(), undefined)
})

test('failed writes do not refresh or erase local controls, and disconnected pages do not refresh', () => {
  const state = setup()
  const mutation = request(state, 'POST', 'https://trove.example/tv_episodes/9/toggle_watched')
  response(state, mutation, false, false); state.flush()
  assert.equal(state.frame.src, '')
  response(state, mutation, true)
  state.root.isConnected = false; state.controller.disconnect(); state.flush()
  assert.equal(state.frame.src, '')
  assert.equal(state.listeners.size, 0)
})

test('responses belonging to a prior title cannot update the current series', () => {
  const state = setup()
  assert.equal(response(state, 'previous-title:2', true), true)
  state.flush()
  assert.equal(state.frame.src, '')
})


test('typing a new filter invalidates a pending read before the search debounce submits', () => {
  const state = setup()
  const old = request(state, 'GET', 'https://trove.example/tv_shows/1?season=0')
  state.controller.intent({ target: { action: 'https://trove.example/tv_shows/1#media-entries',
    entries: [['season', '1'], ['child_q', 'Finale'], ['child_status', 'all']] } })
  assert.equal(response(state, old), true)
  state.controller.refresh(); state.flush()
  assert.equal(new URL(state.frame.src).searchParams.get('season'), '1')
  assert.equal(new URL(state.frame.src).searchParams.get('child_q'), 'Finale')
})
