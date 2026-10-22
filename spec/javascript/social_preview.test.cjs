const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')

const source = readFileSync('app/javascript/controllers/social_preview_controller.js', 'utf8')
  .replace(/^import .*\n/gm, '').replace('export default class', 'return class')

test('social_preview_controller sets data-connected="true", configures aria-live, and updates character count preview', () => {
  const element = { dataset: {} }
  const countTarget = {
    attributes: {},
    setAttribute(name, val) { this.attributes[name] = val },
    textContent: ''
  }
  const outputTarget = { textContent: '' }
  const inputTarget = { value: 'Checking [title]' }

  const Controller = new Function('Controller', source)(class {})
  const instance = Object.create(Controller.prototype)
  instance.element = element
  instance.inputTarget = inputTarget
  instance.outputTarget = outputTarget
  instance.countTarget = countTarget
  instance.hasOutputTarget = true
  instance.hasCountTarget = true
  instance.defaultValue = ''
  instance.limitValue = 300

  instance.connect()

  assert.equal(element.dataset.connected, 'true')
  assert.equal(countTarget.attributes['aria-live'], 'polite')
  assert.equal(outputTarget.textContent, 'Checking The Grand Budapest Hotel')
  assert.match(countTarget.textContent, /^33\/300 characters in this sample/)
})
