const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')

function setup(options = {}) {
  const frames = new Map()
  const document = {
    body: { style: {}, children: [] },
    activeElement: null,
    querySelector: () => null
  }
  const control = () => ({ isConnected: true, disabled: false, getClientRects: () => [1],
    focus() { document.activeElement = this } })
  const opener = control(), close = control(), title = control()
  document.activeElement = opener
  const heading = options.heading !== undefined ? options.heading : { textContent: 'Log Book' }
  const attributes = {}
  const dialog = {
    setAttribute(k, v) { attributes[k] = v },
    getAttribute(k) { return attributes[k] },
    querySelector: (sel) => sel === "h2" ? heading : null,
    contains: element => [close, title].includes(element)
  }
  const eventListeners = {}
  const element = {
    isConnected: true,
    dataset: {},
    querySelector: () => dialog,
    querySelectorAll: () => [close, title],
    addEventListener(name, fn) { eventListeners[name] = fn },
    removeEventListener(name) { delete eventListeners[name] }
  }
  const source = fs.readFileSync('app/javascript/controllers/modal_controller.js', 'utf8')
    .replace(/^import .*\n/gm, '').replace('export default class', 'return class')
  const Class = new Function('Controller', 'window', 'document', 'requestAnimationFrame', 'cancelAnimationFrame', source)(
    class {}, {}, document, callback => { frames.set(1, callback); return 1 }, id => frames.delete(id))
  const controller = new Class()
  controller.element = element
  return { controller, document, opener, close, title, dialog, heading, attributes, eventListeners, flush: () => { for (const callback of frames.values()) callback() } }
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

test('associates dialog with h2 heading via aria-labelledby and assigns id if missing', () => {
  const heading = { textContent: 'Log Book' }
  const s = setup({ heading })
  s.controller.connect()
  assert.equal(s.attributes['role'], 'dialog')
  assert.equal(s.attributes['aria-modal'], 'true')
  assert.ok(heading.id.startsWith('modal-heading-'))
  assert.equal(s.attributes['aria-labelledby'], heading.id)
})

test('falls back to aria-label if no heading exists in dialog', () => {
  const s = setup({ heading: null })
  s.controller.connect()
  assert.equal(s.attributes['role'], 'dialog')
  assert.equal(s.attributes['aria-modal'], 'true')
  assert.equal(s.attributes['aria-label'], 'Add to library')
})

test('pressing Escape inside modal invokes close', () => {
  const s = setup()
  s.controller.connect()
  let closed = false
  s.controller.close = (event) => { closed = true }
  const event = { key: 'Escape', preventDefault() {} }
  s.controller.trap(event)
  assert.equal(closed, true)
})
