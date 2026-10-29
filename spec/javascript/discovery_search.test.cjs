const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const source = readFileSync('app/javascript/controllers/discovery_search_controller.js', 'utf8')
  .replace(/^import .*\n/gm, '').replace('export default class', 'return class')

function controller(fetch) {
  const Search = new Function('Controller', 'fetch', 'AbortController', 'URLSearchParams', 'setTimeout', source)(
    class {}, fetch, AbortController, URLSearchParams, callback => callback()
  )
  const instance = new Search()
  Object.assign(instance, { queryValue: 'Madonna', typeValue: 'album', client: 'synthetic-client',
    statusTarget: { textContent: '' }, retryTarget: { hidden: true }, rendered: [] })
  instance.renderResults = results => { instance.rendered = results }
  return instance
}
const response = (title, status = 200) => ({ ok: true, status, json: async () => ({
  results: [{ title, api_id: title, source: 'itunes' }], sources: [{ source: 'itunes', state: 'ready' }]
}) })

test('obsolete searches cannot replace a newer query after back/navigation or rapid changes', async () => {
  let finishOld
  let requests = 0
  const search = controller(() => ++requests === 1 ? new Promise(resolve => { finishOld = resolve }) : response('Buckethead fixture'))
  const old = search.search()
  search.queryValue = 'Buckethead'
  await search.search()
  finishOld(response('Madonna fixture'))
  await old
  assert.equal(search.rendered[0].title, 'Buckethead fixture')
  assert.match(search.statusTarget.textContent, /not a complete catalog/)
})

test('a provider polling failure keeps previously rendered partial results and exposes retry', async () => {
  let requests = 0
  const search = controller(() => ++requests === 1 ? response('Partial fixture', 202) : { ok: false })
  await search.search()
  assert.equal(search.rendered[0].title, 'Partial fixture')
  assert.equal(search.retryTarget.hidden, false)
  assert.match(search.statusTarget.textContent, /unavailable or taking too long/)
})

test('disconnect aborts pending discovery without clearing the visible results', async () => {
  let finish
  const search = controller(() => new Promise(resolve => { finish = resolve }))
  const pending = search.search()
  search.disconnect()
  finish(response('Late fixture'))
  await pending
  assert.deepEqual(search.rendered, [])
  assert.equal(search.abort.signal.aborted, true)
})
