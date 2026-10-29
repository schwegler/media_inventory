const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')

const source = readFileSync('app/javascript/controllers/metadata_tabs_controller.js', 'utf8')
  .replace(/^import .*\n/gm, '').replace('export default class', 'return class')

function createMockExpandButton() {
  const attributes = {}
  return {
    hidden: true,
    textContent: '',
    attributes,
    setAttribute(name, value) { attributes[name] = String(value) },
    getAttribute(name) { return attributes[name] }
  }
}

test('metadata_tabs_controller sets data-connected="true" on connect and synchronizes aria-expanded and aria-controls on expandTarget', () => {
  const expandTarget = createMockExpandButton()
  const listTarget = {
    attributes: {},
    setAttribute(name, value) { this.attributes[name] = String(value) },
    removeAttribute(name) { delete this.attributes[name] }
  }
  const tab1 = { setAttribute() {}, removeAttribute() {}, id: 'tab-1', hash: '#panel-1' }
  const tab2 = { setAttribute() {}, removeAttribute() {}, id: 'tab-2', hash: '#panel-2' }
  const panel1 = { setAttribute() {}, removeAttribute() {}, id: 'panel-1', querySelector: () => null }
  const panel2 = { setAttribute() {}, removeAttribute() {}, id: 'panel-2', querySelector: () => null }

  const element = {
    id: 'title-details',
    dataset: {},
    getBoundingClientRect: () => ({ height: 100 }),
    contains: () => false,
    compareDocumentPosition: () => 0
  }

  global.CSS = { escape: (str) => str }
  global.document = {
    documentElement: { onbeforematch: true },
    getElementById: () => null
  }
  global.location = { hash: '', pathname: '/movies/1', search: '' }
  global.window = {
    addEventListener: () => {},
    removeEventListener: () => {},
    location: global.location
  }
  global.history = {
    state: null,
    replaceState: () => {},
    pushState: () => {}
  }

  const Controller = new Function('Controller', source)(class {})
  const instance = Object.create(Controller.prototype)
  instance.element = element
  instance.expandTarget = expandTarget
  instance.hasExpandTarget = true
  instance.listTarget = listTarget
  instance.tabTargets = [tab1, tab2]
  instance.panelTargets = [panel1, panel2]

  instance.connect()

  // Verify connection flag
  assert.equal(element.dataset.connected, 'true')

  // Verify initial state: compact/tabbed mode -> aria-expanded="false"
  assert.equal(expandTarget.hidden, false)
  assert.equal(expandTarget.textContent, 'Show all')
  assert.equal(expandTarget.getAttribute('aria-expanded'), 'false')
  assert.equal(expandTarget.getAttribute('aria-controls'), 'title-details')

  // Toggle expand() to switch to expanded mode -> aria-expanded="true"
  instance.expand()
  assert.equal(expandTarget.textContent, 'Show tabs')
  assert.equal(expandTarget.getAttribute('aria-expanded'), 'true')
  assert.equal(expandTarget.getAttribute('aria-controls'), 'title-details')

  // Toggle expand() back to tabbed mode -> aria-expanded="false"
  instance.expand()
  assert.equal(expandTarget.textContent, 'Show all')
  assert.equal(expandTarget.getAttribute('aria-expanded'), 'false')
  assert.equal(expandTarget.getAttribute('aria-controls'), 'title-details')
})
