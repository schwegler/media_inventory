const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')

const source = readFileSync('app/javascript/controllers/tabs_controller.js', 'utf8')
  .replace(/^import .*\n/gm, '').replace('export default class', 'return class')

function createDummyTab(name, active = false) {
  let focused = false
  const classList = new Set(active ? ['active'] : [])
  const dataset = { tabName: name }
  const attributes = {}
  return {
    dataset,
    classList: {
      contains: (cls) => classList.has(cls),
      toggle: (cls, force) => {
        if (force === undefined) {
          if (classList.has(cls)) classList.delete(cls)
          else classList.add(cls)
        } else if (force) classList.add(cls)
        else classList.delete(cls)
        return classList.has(cls)
      }
    },
    attributes,
    setAttribute(name, val) { attributes[name] = val },
    getAttribute(name) { return attributes[name] },
    focus() { focused = true },
    get isFocused() { return focused }
  }
}

function createDummyContent(name) {
  let focusedInput = null
  const dummyInput = {
    focus() { focusedInput = this }
  }
  const classList = new Set(['hidden'])
  const dataset = { tabName: name }
  const attributes = {}
  return {
    dataset,
    hidden: true,
    classList: {
      toggle: (cls, force) => {
        if (force === undefined) {
          if (classList.has(cls)) classList.delete(cls)
          else classList.add(cls)
        } else if (force) classList.add(cls)
        else classList.delete(cls)
        return classList.has(cls)
      },
      contains: (cls) => classList.has(cls)
    },
    attributes,
    setAttribute(name, val) { attributes[name] = val },
    getAttribute(name) { return attributes[name] },
    querySelector(selector) {
      if (selector.includes('input')) return dummyInput
      return null
    },
    get focusedInput() { return focusedInput }
  }
}

test('tabs_controller sets data-connected="true", synchronizes ARIA attributes, shifts focus to input on switch, and handles keyboard navigation', () => {
  const listeners = {}
  const parentElement = {
    classList: { contains: () => false },
    attributes: {},
    setAttribute(name, val) { this.attributes[name] = val },
    addEventListener(event, handler) { listeners[event] = handler },
    removeEventListener(event, handler) { if (listeners[event] === handler) delete listeners[event] }
  }

  const tab1 = createDummyTab('email', true)
  tab1.parentElement = parentElement
  const tab2 = createDummyTab('bsky-oauth', false)
  tab2.parentElement = parentElement

  const content1 = createDummyContent('email')
  const content2 = createDummyContent('bsky-oauth')

  const element = { dataset: {} }

  // Set up mock window.location
  global.window = { location: { href: 'http://localhost/login' } }

  const Controller = new Function('Controller', source)(class {})
  const instance = Object.create(Controller.prototype)
  instance.element = element
  instance.tabTarget = tab1
  instance.tabTargets = [tab1, tab2]
  instance.contentTargets = [content1, content2]

  instance.connect()

  // Verify connection & initialization
  assert.equal(element.dataset.connected, 'true')
  assert.equal(parentElement.attributes['role'], 'tablist')
  assert.equal(parentElement.attributes['aria-label'], 'Sign in method')

  // ARIA attributes on tabs
  assert.equal(tab1.attributes['role'], 'tab')
  assert.equal(tab1.attributes['aria-selected'], 'true')
  assert.equal(tab1.tabIndex, 0)
  assert.equal(tab2.attributes['role'], 'tab')
  assert.equal(tab2.attributes['aria-selected'], 'false')
  assert.equal(tab2.tabIndex, -1)

  // ARIA attributes on tabpanels
  assert.equal(content1.attributes['role'], 'tabpanel')
  assert.equal(content1.hidden, false)
  assert.equal(content1.classList.contains('hidden'), false)

  assert.equal(content2.attributes['role'], 'tabpanel')
  assert.equal(content2.hidden, true)
  assert.equal(content2.classList.contains('hidden'), true)

  // Test explicit tab switching via user click event automatically focuses input in active panel
  instance.switch({ currentTarget: tab2 })
  assert.equal(tab1.attributes['aria-selected'], 'false')
  assert.equal(tab1.tabIndex, -1)
  assert.equal(content1.hidden, true)

  assert.equal(tab2.attributes['aria-selected'], 'true')
  assert.equal(tab2.tabIndex, 0)
  assert.equal(content2.hidden, false)
  assert.notEqual(content2.focusedInput, null)

  // Test keyboard navigation (ArrowLeft)
  let defaultPrevented = false
  listeners['keydown']({
    target: tab2,
    key: 'ArrowLeft',
    preventDefault() { defaultPrevented = true }
  })
  assert.ok(defaultPrevented)
  assert.equal(tab1.attributes['aria-selected'], 'true')
  assert.ok(tab1.isFocused)

  // Disconnect cleans up event listeners
  instance.disconnect()
  assert.equal(listeners['keydown'], undefined)
})
