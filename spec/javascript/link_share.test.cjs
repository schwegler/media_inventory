const { test, beforeEach } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')

beforeEach((t) => t.mock.timers.enable({ apis: ['setTimeout'] }))

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
    getAttribute(name) { return attributes[name] ?? null },
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

test('copy writes the link and restores its accessible name after feedback', async (t) => {
  const { instance, status, getClipboardText } = createMockController()
  const button = createMockButton('Copy item link')
  await instance.copy({ currentTarget: button })
  assert.equal(getClipboardText(), 'https://example.com/item/42')
  assert.equal(status.textContent, 'Link copied.')
  assert.equal(button.getAttribute('aria-label'), 'Copied!')
  t.mock.timers.tick(2000)
  assert.equal(button.getAttribute('aria-label'), 'Copy item link')
  assert.equal(status.textContent, '')
  assert.equal(instance.copyTimeout, null)
})

for (const label of [null, '', 'Copy link']) {
  test(`rapid clicks restore original label ${JSON.stringify(label)} after the last click`, async (t) => {
    const { instance } = createMockController()
    const button = createMockButton(label)
    await instance.copy({ currentTarget: button })
    t.mock.timers.tick(1500)
    await instance.copy({ currentTarget: button })
    t.mock.timers.tick(500)
    assert.equal(button.getAttribute('aria-label'), 'Copied!')
    t.mock.timers.tick(1500)
    assert.equal(button.getAttribute('aria-label'), label)
    assert.equal(button.hasAttribute('aria-label'), label !== null)
    assert.equal(instance.copyTimeout, null)
    // A later cycle must capture the current label rather than stale state.
    button.setAttribute('aria-label', 'Updated copy label')
    await instance.copy({ currentTarget: button })
    t.mock.timers.tick(2000)
    assert.equal(button.getAttribute('aria-label'), 'Updated copy label')
  })
}

test('disconnect restores the button and cancels pending feedback', async (t) => {
  const { instance, status } = createMockController()
  const button = createMockButton(null)
  await instance.copy({ currentTarget: button })
  instance.disconnect()
  assert.equal(button.hasAttribute('aria-label'), false)
  assert.equal(instance.copyTimeout, null)
  assert.equal(instance.timeout, null)
  status.textContent = 'Reconnected status'
  button.setAttribute('aria-label', 'Reconnected label')
  t.mock.timers.tick(2000)
  assert.equal(status.textContent, 'Reconnected status')
  assert.equal(button.getAttribute('aria-label'), 'Reconnected label')
})

test('copying with another button restores the previous button immediately', async (t) => {
  const { instance } = createMockController()
  const first = createMockButton('First')
  const second = createMockButton('Second')
  await instance.copy({ currentTarget: first })
  await instance.copy({ currentTarget: second })
  assert.equal(first.getAttribute('aria-label'), 'First')
  assert.equal(second.getAttribute('aria-label'), 'Copied!')
  t.mock.timers.tick(2000)
  assert.equal(second.getAttribute('aria-label'), 'Second')
})
