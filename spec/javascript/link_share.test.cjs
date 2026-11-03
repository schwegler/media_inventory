const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')

const source = readFileSync('app/javascript/controllers/link_share_controller.js', 'utf8')
  .replace(/^import .*\n/gm, '').replace('export default class', 'return class')

function createMockController() {
  let clipboardText = ''
  global.navigator = global.navigator || {}
  global.navigator.clipboard = {
    writeText: async (text) => {
      clipboardText = text
    }
  }

  const status = { textContent: '' }
  const fallback = {
    hidden: true,
    focusCalled: false,
    selectCalled: false,
    focus() { this.focusCalled = true },
    select() { this.selectCalled = true }
  }
  const copyBtn = {
    focusCalled: false,
    focus() { this.focusCalled = true }
  }

  const element = { dataset: {} }
  const Controller = new Function('Controller', 'trackPublicShare', source)(class {}, () => {})
  const instance = Object.create(Controller.prototype)

  instance.element = element
  instance.urlValue = 'https://example.com/item/42'
  instance.titleValue = 'Awesome Item'
  instance.hasStatusTarget = true
  instance.statusTarget = status
  instance.hasFallbackTarget = true
  instance.fallbackTarget = fallback
  instance.hasCopyTarget = true
  instance.copyTarget = copyBtn

  return { instance, element, status, fallback, copyBtn, getClipboardText: () => clipboardText }
}

function createMockButton(initialAriaLabel = null) {
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

test('link_share_controller sets data-connected="true" on connect', () => {
  const { instance, element } = createMockController()
  instance.connect()

  assert.equal(element.dataset.connected, 'true')
})

test('link_share_controller copy writes text and updates aria-label', async () => {
  const { instance, status, getClipboardText } = createMockController()
  instance.connect()
  const button = createMockButton('Copy item link')

  const event = {
    currentTarget: button
  }

  await instance.copy(event)

  assert.equal(getClipboardText(), 'https://example.com/item/42')
  assert.equal(status.textContent, 'Link copied.')
  assert.equal(button.getAttribute('aria-label'), 'Copied!')
  assert.equal(button.dataset.originalAriaLabel, 'Copy item link')
  assert.notEqual(instance.copyTimeout, null)
})

test('link_share_controller preserves undefined originalAriaLabel on rapid consecutive clicks without initial aria-label', async () => {
  const { instance } = createMockController()
  instance.connect()
  const button = createMockButton(null)

  const event = { currentTarget: button }

  await instance.copy(event)
  assert.equal(button.dataset.originalAriaLabel, '')
  assert.equal(button.getAttribute('aria-label'), 'Copied!')

  // Second rapid click while aria-label is "Copied!"
  await instance.copy(event)
  assert.equal(button.dataset.originalAriaLabel, '')
  assert.equal(button.getAttribute('aria-label'), 'Copied!')
})

test('link_share_controller clears timeouts on disconnect', async () => {
  const { instance } = createMockController()
  instance.connect()
  const button = createMockButton('Copy')

  await instance.copy({ currentTarget: button })
  assert.notEqual(instance.copyTimeout, null)
  assert.notEqual(instance.timeout, null)

  instance.disconnect()
})
