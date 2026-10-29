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
