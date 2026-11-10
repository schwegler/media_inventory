const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')

function createBackToTopController(windowMock, documentMock) {
  const source = fs.readFileSync('app/javascript/controllers/back_to_top_controller.js', 'utf8')
    .replace(/^import .*\n/gm, '')
    .replace('export default class', 'return class')
  const Class = new Function('Controller', 'window', 'document', 'requestAnimationFrame', 'cancelAnimationFrame', source)(
    class {},
    windowMock,
    documentMock,
    windowMock.requestAnimationFrame,
    windowMock.cancelAnimationFrame
  )
  return new Class()
}

test('back_to_top_controller sets data-connected, checks visibility immediately on connect, and scrolls to top', () => {
  let focused = false
  const button = { hidden: false, dataset: {} }
  const mainContent = { focus: (opts) => { focused = true; assert.equal(opts.preventScroll, true) } }
  let scrolledTo = null
  const windowMock = {
    scrollY: 100,
    scrollTo: (options) => { scrolledTo = options },
    matchMedia: () => ({ matches: false }),
    requestAnimationFrame: (cb) => { cb(); return 1 },
    cancelAnimationFrame: () => {}
  }
  const documentMock = {
    documentElement: { dataset: {} },
    getElementById: (id) => (id === 'main-content' ? mainContent : null)
  }

  const controller = createBackToTopController(windowMock, documentMock)
  controller.element = button

  controller.connect()
  assert.equal(button.dataset.connected, 'true')
  assert.equal(button.hidden, true) // scrollY is 100 < 400

  windowMock.scrollY = 500
  controller.applyVisibility()
  assert.equal(button.hidden, false)

  controller.scrollToTop()
  assert.deepEqual(scrolledTo, { top: 0, behavior: 'smooth' })
  assert.equal(focused, true)
})

test('back_to_top_controller throttles update calls using requestAnimationFrame and cleans up on disconnect', () => {
  const button = { hidden: true, dataset: {} }
  let rafCallbacks = []
  let cancelledId = null
  let nextFrameId = 100

  const windowMock = {
    scrollY: 0,
    requestAnimationFrame: (cb) => {
      const id = ++nextFrameId
      rafCallbacks.push({ id, cb })
      return id
    },
    cancelAnimationFrame: (id) => {
      cancelledId = id
      rafCallbacks = rafCallbacks.filter(item => item.id !== id)
    }
  }
  const documentMock = {
    documentElement: { dataset: {} },
    getElementById: () => null
  }

  const controller = createBackToTopController(windowMock, documentMock)
  controller.element = button

  controller.connect()
  assert.equal(button.hidden, true)
  assert.equal(rafCallbacks.length, 0) // initial connect uses direct applyVisibility()

  // Rapid scrolling triggers update multiple times
  windowMock.scrollY = 600
  controller.update()
  controller.update()
  controller.update()

  assert.equal(rafCallbacks.length, 1, 'Only one requestAnimationFrame is scheduled despite multiple update calls')
  assert.equal(button.hidden, true, 'Visibility has not mutated before the frame executes')

  // Run animation frame
  const frame = rafCallbacks.shift()
  frame.cb()

  assert.equal(button.hidden, false, 'Visibility updated after frame callback')
  assert.equal(controller.frame, null)

  // Trigger another update and disconnect
  controller.update()
  assert.equal(rafCallbacks.length, 1)
  const scheduledId = rafCallbacks[0].id

  controller.disconnect()
  assert.equal(cancelledId, scheduledId, 'Pending animation frame was cancelled on disconnect')
  assert.equal(controller.frame, null)
})
