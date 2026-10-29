const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')

const source = readFileSync('app/javascript/controllers/mobile_menu_controller.js', 'utf8')
  .replace(/^import .*\n/gm, '').replace('export default class', 'return class')

function createMockController() {
  const docListeners = {}
  const windowListeners = {}

  let focusedElement = null

  const createFocusable = (name) => ({
    name,
    attributes: {},
    setAttribute(key, val) { this.attributes[key] = val },
    focus() { focusedElement = this }
  })

  const openerButton = createFocusable('openerButton')
  const mainButton = createFocusable('mainButton')
  const searchInput = createFocusable('searchInput')

  const menu = {
    classList: {
      active: false,
      toggle(cls, val) { this.active = val }
    },
    querySelector(selector) {
      if (selector === 'input') return searchInput
      return null
    }
  }

  const icon = {
    classList: {
      hidden: false,
      toggle(cls, val) { this.hidden = val }
    }
  }

  const closeIcon = {
    classList: {
      hidden: true,
      toggle(cls, val) { this.hidden = val }
    }
  }

  const element = {
    dataset: {},
    contains(target) { return target === menu || target === openerButton }
  }

  const Controller = new Function('Controller', source)(class {})
  const instance = Object.create(Controller.prototype)

  instance.element = element
  instance.menuTarget = menu
  instance.hasIconTarget = true
  instance.iconTarget = icon
  instance.hasCloseIconTarget = true
  instance.closeIconTarget = closeIcon
  instance.hasButtonTarget = true
  instance.buttonTarget = mainButton
  instance.buttonTargets = [mainButton]

  global.window = global.window || { innerWidth: 1000 }
  global.window.addEventListener = (type, handler) => { windowListeners[type] = handler }
  global.window.removeEventListener = (type) => { delete windowListeners[type] }

  global.document = global.document || {}
  global.document.addEventListener = (type, handler) => { docListeners[type] = handler }
  global.document.removeEventListener = (type) => { delete docListeners[type] }

  return {
    instance,
    element,
    menu,
    icon,
    closeIcon,
    openerButton,
    mainButton,
    searchInput,
    docListeners,
    windowListeners,
    getFocusedElement: () => focusedElement
  }
}

test('mobile_menu_controller sets data-connected="true" on connect', () => {
  const { instance, element, docListeners, windowListeners } = createMockController()
  instance.connect()

  assert.equal(element.dataset.connected, 'true')
  assert.equal(typeof docListeners['keydown'], 'function')
  assert.equal(typeof docListeners['click'], 'function')
  assert.equal(typeof docListeners['turbo:before-cache'], 'function')
  assert.equal(typeof windowListeners['resize'], 'function')
})

test('mobile_menu_controller opening and closing menu restores focus to opener', () => {
  const { instance, openerButton, getFocusedElement } = createMockController()
  instance.connect()

  instance.toggle({ currentTarget: openerButton })
  assert.equal(instance.isOpen, true)

  instance.toggle({ currentTarget: openerButton })
  assert.equal(instance.isOpen, false)
  assert.equal(getFocusedElement(), openerButton)
  assert.equal(instance.opener, null)
})

test('mobile_menu_controller openSearch focuses search input and closing restores focus to opener', () => {
  const { instance, openerButton, searchInput, getFocusedElement } = createMockController()
  instance.connect()

  instance.openSearch({ currentTarget: openerButton })
  assert.equal(instance.isOpen, true)
  assert.equal(getFocusedElement(), searchInput)

  instance.close()
  assert.equal(instance.isOpen, false)
  assert.equal(getFocusedElement(), openerButton)
})

test('mobile_menu_controller Escape key closes menu and restores focus', () => {
  const { instance, openerButton, docListeners, getFocusedElement } = createMockController()
  instance.connect()

  instance.toggle({ currentTarget: openerButton })
  assert.equal(instance.isOpen, true)

  docListeners['keydown']({ key: 'Escape' })
  assert.equal(instance.isOpen, false)
  assert.equal(getFocusedElement(), openerButton)
})

test('mobile_menu_controller navigate closes menu without restoring focus', () => {
  const { instance, openerButton, getFocusedElement } = createMockController()
  instance.connect()

  instance.toggle({ currentTarget: openerButton })
  assert.equal(instance.isOpen, true)

  const link = { closest(sel) { return sel === 'a' ? this : null } }
  instance.navigate({ target: link })

  assert.equal(instance.isOpen, false)
  assert.notEqual(getFocusedElement(), openerButton)
})

test('mobile_menu_controller disconnect cleans up event listeners', () => {
  const { instance, docListeners, windowListeners } = createMockController()
  instance.connect()

  assert.equal(typeof docListeners['keydown'], 'function')
  assert.equal(typeof windowListeners['resize'], 'function')

  instance.disconnect()

  assert.equal(Object.keys(docListeners).length, 0)
  assert.equal(Object.keys(windowListeners).length, 0)
})
