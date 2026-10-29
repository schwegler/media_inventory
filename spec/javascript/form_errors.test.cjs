const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')

const source = readFileSync('app/javascript/controllers/form_errors_controller.js', 'utf8')
  .replace(/^import .*\n/gm, '').replace('export default class', 'return class')

test('form_errors_controller shifts focus to #error_explanation and sets accessibility attributes on connect', () => {
  let focused = false
  const summary = {
    id: 'error_explanation',
    role: null,
    tabIndex: null,
    setAttribute(name, value) { this[name] = value },
    focus() { focused = true }
  }

  const inputs = [
    {
      attributes: {},
      setAttribute(name, value) { this.attributes[name] = value },
      getAttribute(name) { return this.attributes[name] }
    }
  ]

  const element = {
    querySelector(selector) {
      if (selector === '#error_explanation') return summary
      return null
    },
    querySelectorAll(selector) {
      if (selector.includes('.field_with_errors')) return inputs
      return []
    }
  }

  const Controller = new Function('Controller', source)(class {})
  const instance = Object.create(Controller.prototype)
  instance.element = element

  instance.connect()

  assert.equal(summary.role, 'alert')
  assert.equal(summary.tabIndex, -1)
  assert.equal(focused, true)
  assert.equal(inputs[0].getAttribute('aria-invalid'), 'true')
  assert.equal(inputs[0].getAttribute('aria-describedby'), 'error_explanation')
})

test('form_errors_controller does nothing if #error_explanation is not present', () => {
  let focused = false
  const element = {
    querySelector() { return null },
    querySelectorAll() { return [] }
  }

  const Controller = new Function('Controller', source)(class {})
  const instance = Object.create(Controller.prototype)
  instance.element = element

  instance.connect()

  assert.equal(focused, false)
})
