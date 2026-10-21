const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')

const source = readFileSync('app/javascript/controllers/flash_controller.js', 'utf8')
  .replace(/^import .*\n/gm, '').replace('export default class', 'return class')

test('flash_controller sets data-connected="true" and listens for Escape key dismissal', () => {
  const listeners = {}

  const element = {
    dataset: {},
    style: {},
    addEventListener(type, handler) { listeners[type] = handler },
    removeEventListener(type) { delete listeners[type] },
    contains() { return false },
    remove() {}
  }

  const Controller = new Function('Controller', source)(class {})
  const instance = Object.create(Controller.prototype)
  instance.element = element
  instance.dismissAfterValue = 0

  instance.connect()

  assert.equal(element.dataset.connected, 'true')
  assert.equal(typeof listeners.keydown, 'function')

  // Simulate Escape key press
  let prevented = false
  listeners.keydown({ key: 'Escape', preventDefault() { prevented = true } })

  assert.equal(prevented, true)
  assert.equal(instance.keydownHandler, null)
  assert.equal(listeners.keydown, undefined)
})

test('flash_controller cleans up event listeners on disconnect', () => {
  const listeners = {}

  const element = {
    dataset: {},
    style: {},
    addEventListener(type, handler) { listeners[type] = handler },
    removeEventListener(type) { delete listeners[type] }
  }

  const Controller = new Function('Controller', source)(class {})
  const instance = Object.create(Controller.prototype)
  instance.element = element
  instance.dismissAfterValue = 0

  instance.connect()
  assert.equal(typeof listeners.keydown, 'function')

  instance.disconnect()
  assert.equal(listeners.keydown, undefined)
})
