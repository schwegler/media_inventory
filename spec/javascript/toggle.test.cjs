const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')

const source = readFileSync('app/javascript/controllers/toggle_controller.js', 'utf8')
  .replace(/^import .*\n/gm, '').replace('export default class', 'return class')

test('toggle_controller connects, expands/collapses targets, and dismisses on Escape keypress', () => {
  let focusedElement = null
  const listeners = {}

  const element = {
    dataset: {},
    addEventListener(name, handler) { listeners[name] = handler },
    removeEventListener(name, handler) { if (listeners[name] === handler) delete listeners[name] }
  }

  const triggerTarget = {
    attributes: {},
    setAttribute(name, val) { this.attributes[name] = val },
    focus() { focusedElement = this }
  }

  const inputElement = {
    focus() { focusedElement = this }
  }

  const targetContainer = {
    classes: new Set(['hidden']),
    classList: {
      contains(cls) { return targetContainer.classes.has(cls) },
      add(cls) { targetContainer.classes.add(cls) },
      remove(cls) { targetContainer.classes.delete(cls) },
      toggle(cls) {
        if (targetContainer.classes.has(cls)) {
          targetContainer.classes.delete(cls)
          return false
        } else {
          targetContainer.classes.add(cls)
          return true
        }
      }
    },
    querySelector(selector) {
      if (selector.includes('input')) return inputElement
      return null
    }
  }

  const Controller = new Function('Controller', source)(class {})
  const instance = Object.create(Controller.prototype)
  instance.element = element
  instance.elementTargets = [targetContainer]
  instance.triggerTargets = [triggerTarget]
  instance.triggerTarget = triggerTarget
  instance.inputTargets = []
  instance.hasTriggerTarget = true
  instance.hasInputTarget = false
  instance.hiddenClass = 'hidden'

  // Connect
  instance.connect()
  assert.equal(element.dataset.connected, 'true')
  assert.ok(typeof listeners.keydown === 'function')

  // Toggle open
  instance.toggle({ preventDefault() {} })
  assert.equal(targetContainer.classes.has('hidden'), false)
  assert.equal(triggerTarget.attributes['aria-expanded'], 'true')
  assert.equal(focusedElement, inputElement)

  // Press Escape to dismiss
  let prevented = false
  listeners.keydown({
    key: 'Escape',
    preventDefault() { prevented = true }
  })

  assert.equal(targetContainer.classes.has('hidden'), true)
  assert.equal(triggerTarget.attributes['aria-expanded'], 'false')
  assert.equal(focusedElement, triggerTarget)
  assert.equal(prevented, true)

  // Disconnect cleans up listener
  instance.disconnect()
  assert.equal(listeners.keydown, undefined)
})
