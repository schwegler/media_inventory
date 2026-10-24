const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')

const source = readFileSync('app/javascript/controllers/consumed_toggle_controller.js', 'utf8')
  .replace(/^import .*\n/gm, '').replace('export default class', 'return class')

test('consumed_toggle_controller sets data-connected="true", synchronizes ARIA attributes, and shifts focus on user interaction', () => {
  let focusedElement = null
  const dateInput = {
    focus() { focusedElement = this }
  }
  const dateRowTarget = {
    style: {},
    attributes: {},
    id: '',
    setAttribute(name, val) { this.attributes[name] = val },
    querySelector(selector) {
      if (selector.includes('input')) return dateInput
      return null
    }
  }
  const checkboxTarget = {
    checked: false,
    attributes: {},
    setAttribute(name, val) { this.attributes[name] = val }
  }
  const element = { dataset: {} }

  const Controller = new Function('Controller', source)(class {})
  const instance = Object.create(Controller.prototype)
  instance.element = element
  instance.checkboxTarget = checkboxTarget
  instance.dateRowTarget = dateRowTarget
  instance.hasCheckboxTarget = true
  instance.hasDateRowTarget = true

  // Initial connect when checkbox is unchecked
  instance.connect()

  assert.equal(element.dataset.connected, 'true')
  assert.equal(dateRowTarget.style.display, 'none')
  assert.equal(checkboxTarget.attributes['aria-expanded'], 'false')
  assert.equal(dateRowTarget.attributes['aria-hidden'], 'true')
  assert.ok(dateRowTarget.id.startsWith('consumed-date-row-'))
  assert.equal(checkboxTarget.attributes['aria-controls'], dateRowTarget.id)
  assert.equal(focusedElement, null)

  // Toggle checked via user interaction event
  checkboxTarget.checked = true
  const dummyEvent = { type: 'change' }
  instance.toggle(dummyEvent)

  assert.equal(dateRowTarget.style.display, 'block')
  assert.equal(checkboxTarget.attributes['aria-expanded'], 'true')
  assert.equal(dateRowTarget.attributes['aria-hidden'], 'false')
  assert.equal(focusedElement, dateInput)
})
