const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')

const source = readFileSync('app/javascript/controllers/dropdown_controller.js', 'utf8')
  .replace(/^import .*\n/gm, '').replace('export default class', 'return class')

function createMockController() {
  const docListeners = {}
  const menuListeners = {}

  const button = {
    attributes: {},
    focused: false,
    setAttribute(name, value) { this.attributes[name] = value },
    focus() { this.focused = true }
  }

  const menuItem = {
    focused: false,
    focus() { this.focused = true }
  }

  const menu = {
    style: { display: 'none' },
    listeners: menuListeners,
    addEventListener(type, handler) { menuListeners[type] = handler },
    removeEventListener(type) { delete menuListeners[type] },
    querySelector(selector) {
      if (selector === '[role="menuitem"]') return menuItem
      return null
    },
    querySelectorAll() { return [menuItem] },
    contains(target) { return target === menuItem }
  }

  const element = {
    dataset: {},
    contains(target) { return target === button || target === menu || target === menuItem }
  }

  const Controller = new Function('Controller', source)(class {})
  const instance = Object.create(Controller.prototype)

  instance.element = element
  instance.hasMenuTarget = true
  instance.menuTarget = menu
  instance.hasButtonTarget = true
  instance.buttonTarget = button

  // Mock document event listeners
  const originalAddEventListener = global.document?.addEventListener
  const originalRemoveEventListener = global.document?.removeEventListener

  global.document = global.document || {}
  global.document.addEventListener = (type, handler) => { docListeners[type] = handler }
  global.document.removeEventListener = (type) => { delete docListeners[type] }

  return { instance, element, button, menu, menuItem, docListeners, menuListeners }
}

test('dropdown_controller sets data-connected="true" and hides menu on connect', () => {
  const { instance, element, button, menu, docListeners, menuListeners } = createMockController()

  instance.connect()

  assert.equal(element.dataset.connected, 'true')
  assert.equal(menu.style.display, 'none')
  assert.equal(button.attributes['aria-expanded'], 'false')
  assert.equal(typeof docListeners['click'], 'function')
  assert.equal(typeof docListeners['keydown'], 'function')
  assert.equal(typeof docListeners['turbo:before-cache'], 'function')
  assert.equal(typeof menuListeners['click'], 'function')
})

test('dropdown_controller menuClick hides menu when clicking a menu item', () => {
  const { instance, menu, button } = createMockController()
  instance.connect()

  instance.show()
  assert.equal(menu.style.display, 'block')
  assert.equal(button.attributes['aria-expanded'], 'true')

  const link = { closest(sel) { return sel.includes('a') ? this : null } }
  instance.menuClick({ target: link })

  assert.equal(menu.style.display, 'none')
  assert.equal(button.attributes['aria-expanded'], 'false')
})

test('dropdown_controller turbo:before-cache hides menu before caching', () => {
  const { instance, menu, docListeners } = createMockController()
  instance.connect()

  instance.show()
  assert.equal(menu.style.display, 'block')

  docListeners['turbo:before-cache']()
  assert.equal(menu.style.display, 'none')
})

test('dropdown_controller disconnect removes event listeners', () => {
  const { instance, docListeners, menuListeners } = createMockController()
  instance.connect()

  assert.equal(typeof docListeners['click'], 'function')
  assert.equal(typeof menuListeners['click'], 'function')

  instance.disconnect()

  assert.equal(Object.keys(docListeners).length, 0)
  assert.equal(Object.keys(menuListeners).length, 0)
})
