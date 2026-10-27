const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')

const source = readFileSync('app/javascript/controllers/disclosure_menu_controller.js', 'utf8')
  .replace(/^import .*\n/gm, '').replace('export default class', 'return class')

function createMockController() {
  const docListeners = {}
  const elementListeners = {}

  const summary = {
    contains(target) { return target === summary }
  }

  const linkItem = {
    closest(selector) {
      if (selector.includes('a')) return linkItem
      return null
    }
  }

  const element = {
    open: true,
    dataset: {},
    contains(target) { return target === summary || target === linkItem || target === element },
    querySelector(selector) {
      if (selector === 'summary') return summary
      return null
    },
    addEventListener(type, handler) { elementListeners[type] = handler },
    removeEventListener(type) { delete elementListeners[type] }
  }

  const Controller = new Function('Controller', source)(class {})
  const instance = Object.create(Controller.prototype)
  instance.element = element

  global.document = global.document || {}
  global.document.addEventListener = (type, handler) => { docListeners[type] = handler }
  global.document.removeEventListener = (type) => { delete docListeners[type] }

  return { instance, element, summary, linkItem, docListeners, elementListeners }
}

test('disclosure_menu_controller sets data-connected="true" on connect', () => {
  const { instance, element, docListeners, elementListeners } = createMockController()

  instance.connect()

  assert.equal(element.dataset.connected, 'true')
  assert.equal(typeof docListeners['turbo:before-cache'], 'function')
  assert.equal(typeof docListeners['pointerdown'], 'function')
  assert.equal(typeof elementListeners['keydown'], 'function')
  assert.equal(typeof elementListeners['click'], 'function')
})

test('disclosure_menu_controller closes menu when clicking an internal link or button', () => {
  const { instance, element, linkItem, elementListeners } = createMockController()
  instance.connect()

  element.open = true
  elementListeners['click']({ target: linkItem })

  assert.equal(element.open, false)
})

test('disclosure_menu_controller ignores clicks on summary', () => {
  const { instance, element, summary, elementListeners } = createMockController()
  instance.connect()

  element.open = true
  const summaryClickTarget = {
    closest(selector) {
      if (selector.includes('summary')) return summary
      return null
    }
  }
  elementListeners['click']({ target: summaryClickTarget })

  assert.equal(element.open, true)
})

test('disclosure_menu_controller closes menu on turbo:before-cache', () => {
  const { instance, element, docListeners } = createMockController()
  instance.connect()

  element.open = true
  docListeners['turbo:before-cache']()

  assert.equal(element.open, false)
})

test('disclosure_menu_controller cleans up event listeners on disconnect', () => {
  const { instance, docListeners, elementListeners } = createMockController()
  instance.connect()

  assert.equal(typeof elementListeners['click'], 'function')

  instance.disconnect()

  assert.equal(Object.keys(elementListeners).length, 0)
  assert.equal(Object.keys(docListeners).length, 0)
})
