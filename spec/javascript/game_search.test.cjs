const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const source = fs.readFileSync('app/javascript/controllers/thumbnail_fetcher_controller.js', 'utf8')
  .replace(/^import .*\n/gm, '').replace('export default class', 'return class')
const Class = new Function('Controller', 'fetch', source)

function setup(fetch = async () => {}) {
  const controller = new (Class(class {}, fetch))()
  controller.searchStageActive = true
  controller.titleInputTarget = { value: 'spider-man miles' }
  controller.mediaTypeValue = 'video_game'
  controller.statusTextTarget = { textContent: '', classList: { add() {}, remove() {} } }
  controller.optionsGridTarget = { innerHTML: '' }
  controller.searchQuery = () => 'spider-man miles'
  return controller
}

test('the log modal requests source outcomes and renders fallback results with their outcomes', async () => {
  let request, rendered
  const results = [{ title: 'Marvel’s Spider-Man: Miles Morales', source: 'Wikipedia' }]
  const sources = [{ source: 'Steam', state: 'unavailable' }, { source: 'RAWG', state: 'unconfigured' }]
  const controller = setup(async url => {
    request = url
    return { ok: true, status: 200, json: async () => ({ results, sources }) }
  })
  controller.renderResults = (...args) => { rendered = args }
  await controller.fetchThumbnails()
  assert.match(request, /sources=1/)
  assert.deepEqual(rendered, [results, 'video_game', false, sources])
})

test('the log modal distinguishes provider failure, rate limits, configuration and disabled sources', () => {
  const controller = setup()
  const notice = controller.sourceNotice([
    { source: 'Steam', state: 'unavailable' }, { source: 'RAWG', state: 'unconfigured' },
    { source: 'Limited', state: 'rate_limited' }, { source: 'Disabled', state: 'disabled' },
    { source: 'Wikipedia', state: 'ready' }
  ])
  assert.match(notice, /Steam is temporarily unavailable/)
  assert.match(notice, /RAWG is not configured/)
  assert.match(notice, /Limited is rate limited/)
  assert.match(notice, /Disabled is disabled/)
  assert.doesNotMatch(notice, /Wikipedia/)
  controller.renderResults([], 'video_game', false, [{ source: 'Steam', state: 'unavailable' }])
  assert.match(controller.statusTextTarget.textContent, /No matches found.*Steam is temporarily unavailable/)
})
