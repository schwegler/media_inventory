const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')

test('Turbo snapshots are cleared when the viewer changes even with identical preferences', () => {
  const listeners = {}, clears = []
  const document = { addEventListener: (name, callback) => { listeners[name] = callback },
    body: { dataset: { viewerId: '1' } }, documentElement: { dataset: { theme: 'light' } }, querySelectorAll: () => [] }
  const source = fs.readFileSync('app/javascript/application.js', 'utf8').replace(/^import .*\n/gm, '')
  new Function('document', 'window', source)(document, { Turbo: { cache: { clear: () => clears.push(true) } } })
  const render = viewerId => listeners['turbo:before-render']({ detail: { newBody: {
    dataset: { viewerId, uiPreferences: JSON.stringify({ theme: 'light' }) }
  } } })
  render('1')
  assert.equal(clears.length, 0)
  render('2')
  assert.equal(clears.length, 1)
  render('guest')
  assert.equal(clears.length, 2)
})
