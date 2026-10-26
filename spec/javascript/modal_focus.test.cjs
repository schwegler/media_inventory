const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')

function setup() {
  const frames = new Map()
  const document = { body: { style: {}, children: [] }, activeElement: null }
  const control = () => ({ isConnected: true, disabled: false, getClientRects: () => [1],
    focus() { document.activeElement = this } })
  const opener = control(), close = control(), title = control()
  document.activeElement = opener
  const dialog = { setAttribute() {}, querySelector: () => ({ textContent: 'Log Book' }),
    contains: element => [close, title].includes(element) }
  const element = { isConnected: true, dataset: {}, querySelector: () => dialog,
    querySelectorAll: () => [close, title], addEventListener() {}, removeEventListener() {} }
  const source = fs.readFileSync('app/javascript/controllers/modal_controller.js', 'utf8')
    .replace(/^import .*\n/gm, '').replace('export default class', 'return class')
  const Class = new Function('Controller', 'window', 'document', 'requestAnimationFrame', 'cancelAnimationFrame', source)(
    class {}, {}, document, callback => { frames.set(1, callback); return 1 }, id => frames.delete(id))
  const controller = new Class()
  controller.element = element
  return { controller, document, opener, close, title, flush: () => { for (const callback of frames.values()) callback() } }
}

test('opening a modal moves outside focus into the dialog', () => {
  const s = setup()
  s.controller.connect()
  s.flush()
  assert.equal(s.document.activeElement, s.close)
})

test('deferred modal autofocus preserves focus already placed in its title input', () => {
  const s = setup()
  s.controller.connect()
  s.title.focus()
  s.flush()
  assert.equal(s.document.activeElement, s.title)
})

test('closing before the first frame cannot move focus back into the closed dialog', () => {
  const s = setup()
  s.controller.connect()
  s.controller.disconnect()
  s.flush()
  assert.equal(s.document.activeElement, s.opener)
})
