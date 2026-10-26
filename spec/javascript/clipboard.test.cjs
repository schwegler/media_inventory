const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')

const source = readFileSync('app/javascript/controllers/clipboard_controller.js', 'utf8')
  .replace(/^import .*\n/gm, '').replace('export default class', 'return class')

function createMockController() {
  let clipboardText = ''
  global.navigator = global.navigator || {}
  global.navigator.clipboard = {
    writeText: async (text) => {
      clipboardText = text
    }
  }

  const copyIcon = {
    hidden: false,
    classList: {
      add(cls) { if (cls === 'hidden') copyIcon.hidden = true },
      remove(cls) { if (cls === 'hidden') copyIcon.hidden = false }
    }
  }

  const checkIcon = {
    hidden: true,
    classList: {
      add(cls) { if (cls === 'hidden') checkIcon.hidden = true },
      remove(cls) { if (cls === 'hidden') checkIcon.hidden = false }
    }
  }

  const element = {
    dataset: {}
  }

  const Controller = new Function('Controller', source)(class {})
  const instance = Object.create(Controller.prototype)

  instance.element = element
  instance.textValue = 'https://example.com/share'
  instance.hasCopyIconTarget = true
  instance.copyIconTarget = copyIcon
  instance.hasCheckIconTarget = true
  instance.checkIconTarget = checkIcon

  return {
    instance,
    element,
    copyIcon,
    checkIcon,
    getClipboardText: () => clipboardText
  }
}

function createMockButton(initialAriaLabel = 'Copy text') {
  const attributes = initialAriaLabel !== null ? { 'aria-label': initialAriaLabel } : {}
  const dataset = {}

  return {
    dataset,
    getAttribute(name) { return attributes[name] || null },
    setAttribute(name, value) { attributes[name] = value },
    removeAttribute(name) { delete attributes[name] },
    hasAttribute(name) { return name in attributes }
  }
}

test('clipboard_controller sets data-connected="true" on connect', () => {
  const { instance, element } = createMockController()
  instance.connect()

  assert.equal(element.dataset.connected, 'true')
})

test('clipboard_controller copy writes text and updates aria-label and icons', async () => {
  const { instance, copyIcon, checkIcon, getClipboardText } = createMockController()
  instance.connect()
  const button = createMockButton('Copy to clipboard')

  const event = {
    preventDefault() {},
    currentTarget: button
  }

  await instance.copy(event)

  assert.equal(getClipboardText(), 'https://example.com/share')
  assert.equal(button.getAttribute('aria-label'), 'Copied!')
  assert.equal(button.dataset.originalAriaLabel, 'Copy to clipboard')
  assert.equal(copyIcon.hidden, true)
  assert.equal(checkIcon.hidden, false)
  assert.notEqual(instance.copyTimeout, null)
})

test('clipboard_controller preserves empty originalAriaLabel on rapid consecutive clicks', async () => {
  const { instance } = createMockController()
  instance.connect()
  const button = createMockButton(null)

  const event = { preventDefault() {}, currentTarget: button }

  await instance.copy(event)
  assert.equal(button.dataset.originalAriaLabel, '')
  assert.equal(button.getAttribute('aria-label'), 'Copied!')

  // Second click while aria-label is "Copied!"
  await instance.copy(event)
  assert.equal(button.dataset.originalAriaLabel, '')
  assert.equal(button.getAttribute('aria-label'), 'Copied!')
})

test('clipboard_controller disconnect cleans up active timeout', async () => {
  const { instance } = createMockController()
  instance.connect()
  const button = createMockButton('Copy')

  await instance.copy({ preventDefault() {}, currentTarget: button })
  assert.notEqual(instance.copyTimeout, null)

  instance.disconnect()
  assert.equal(instance.copyTimeout, null)
})
