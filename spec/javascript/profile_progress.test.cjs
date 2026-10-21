const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')

function setup() {
  const source = fs.readFileSync('app/javascript/controllers/profile_progress_controller.js', 'utf8')
    .replace(/^import .*\n/gm, '').replace('export default class', 'return class')
  const Class = new Function('Controller', source)(class {})
  const controller = new Class()
  const attributes = new Map()
  controller.element = { setAttribute: (key, value) => attributes.set(key, value), removeAttribute: key => attributes.delete(key) }
  controller.statusTarget = { textContent: '' }
  controller.errorTarget = { hidden: true, textContent: '' }
  return { controller, attributes }
}

test('announces pending work and clears loading on success', () => {
  const { controller, attributes } = setup()
  controller.start()
  assert.equal(attributes.get('aria-busy'), 'true')
  assert.match(controller.statusTarget.textContent, /Updating/)
  controller.finish({ detail: { success: true } })
  assert.equal(attributes.has('aria-busy'), false)
  assert.equal(controller.statusTarget.textContent, '')
  assert.equal(controller.errorTarget.hidden, true)
})

test('shows a recoverable connection failure and clears it on retry', () => {
  const { controller, attributes } = setup()
  controller.start()
  controller.finish({ detail: { success: false } })
  assert.equal(attributes.has('aria-busy'), false)
  assert.equal(controller.errorTarget.hidden, false)
  assert.match(controller.errorTarget.textContent, /try again/)
  controller.start()
  assert.equal(controller.errorTarget.hidden, true)
  controller.error()
  assert.equal(attributes.has('aria-busy'), false)
})
