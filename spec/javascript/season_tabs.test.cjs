const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')

function restore(seasons, storedSeason = null) {
  const source = fs.readFileSync('app/javascript/controllers/season_tabs_controller.js', 'utf8')
    .replace(/^import .*\n/gm, '').replace('export default class', 'return class')
  const Class = new Function('Controller', 'sessionStorage', source)(class {}, { getItem() { return storedSeason } })
  const controller = new Class()
  controller.contentTargets = seasons.map(season => ({ dataset: { season: String(season) } }))
  controller.hasActiveSeasonValue = false
  controller.activeSeasonValue = 0
  controller.hasShowIdValue = true
  controller.showIdValue = 1
  let selected
  controller.switchSeason = season => { selected = season }
  controller.restore()
  return selected
}

test('season tabs default to season one, keeping an explicit saved extras selection', () => {
  assert.equal(restore([0, 1, 2]), 1)
  assert.equal(restore([0, 1, 2], '0'), 0)
})

test('season tabs use existing seasons when season one is absent', () => {
  assert.equal(restore([0, 2026]), 2026)
  assert.equal(restore([0]), 0)
  assert.equal(restore([2, 3]), 2)
  assert.equal(restore([]), undefined)
})

test('season tabs shifts focus when stepping disables the currently focused navigation button', () => {
  const source = fs.readFileSync('app/javascript/controllers/season_tabs_controller.js', 'utf8')
    .replace(/^import .*\n/gm, '').replace('export default class', 'return class')
  let focusedElement = null
  const createButton = () => {
    const btn = {
      disabled: false,
      focus() { focusedElement = btn }
    }
    return btn
  }

  const prevBtn = createButton()
  const nextBtn = createButton()
  const selector = { value: '1', setAttribute() {} }

  global.document = { activeElement: prevBtn }

  const Class = new Function('Controller', 'sessionStorage', source)(
    class { dispatch() {} },
    { getItem() { return null } }
  )
  const controller = new Class()
  controller.tabTargets = []
  controller.contentTargets = [1, 2].map(season => ({
    dataset: { season: String(season) },
    classList: { toggle() {} },
    hidden: false
  }))
  controller.hasPreviousTarget = true
  controller.previousTarget = prevBtn
  controller.hasNextTarget = true
  controller.nextTarget = nextBtn
  controller.hasSelectorTarget = true
  controller.selectorTarget = selector
  controller.hasShowIdValue = false

  // Focus is currently on prevBtn. Switching to season 1 disables prevBtn.
  controller.switchSeason(1)

  assert.equal(prevBtn.disabled, true)
  assert.equal(focusedElement, nextBtn)

  delete global.document
})
