const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')

const source = readFileSync('app/javascript/controllers/header_search_controller.js', 'utf8')
  .replace(/^import .*\n/gm, '').replace('export default class', 'return class')

function fixture({ right = 1116, viewport = 2048, width = 460, origin = 0 } = {}) {
  const properties = new Map(), classes = new Set(['search-open'])
  const controller = new (new Function('Controller', 'document', source)(class {}, {
    documentElement: { clientWidth: viewport }
  }))()
  controller.element = { classList: { contains: name => classes.has(name), remove: name => classes.delete(name) } }
  controller.buttonTarget = {
    getClientRects: () => [1], getBoundingClientRect: () => ({ right, bottom: 56 }),
    setAttribute: (name, value) => { controller.buttonTarget[name] = value }
  }
  controller.panelTarget = {
    offsetParent: { getBoundingClientRect: () => ({ left: origin, top: 12 }), clientLeft: 1, clientTop: 1, scrollLeft: 0, scrollTop: 0 },
    getBoundingClientRect: () => ({ width }),
    style: { setProperty: (key, value) => properties.set(key, value), removeProperty: key => properties.delete(key) }
  }
  return { controller, properties, classes }
}

test('popup follows the trigger instead of the viewport edge, including floating header origins', () => {
  const { controller, properties } = fixture({ origin: 364 })
  controller.positionPanel()
  assert.equal(properties.get('--search-left'), '291px') // 1116 - 460 - 364 - border
  assert.equal(properties.get('--search-top'), '51px') // button bottom + gap - header top - border
  controller.buttonTarget.getBoundingClientRect = () => ({ right: 1016, bottom: 76 })
  controller.positionPanel()
  assert.equal(properties.get('--search-left'), '191px')
  assert.equal(properties.get('--search-top'), '71px')
})

test('popup clamps both viewport edges with a 12px gutter', () => {
  for (const [right, viewport, width, expected] of [[220, 320, 296, 11], [2060, 2048, 460, 1575]]) {
    const { controller, properties } = fixture({ right, viewport, width })
    controller.positionPanel()
    assert.equal(properties.get('--search-left'), `${expected}px`)
  }
})

test('inline breakpoint discards popup state without stealing focus or changing the form', () => {
  const { controller, properties, classes } = fixture()
  controller.positionPanel()
  controller.buttonTarget.getClientRects = () => []
  controller.positionPanel()
  assert.equal(classes.has('search-open'), false)
  assert.equal(controller.buttonTarget['aria-expanded'], 'false')
  assert.equal(properties.size, 0)
})
