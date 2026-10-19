const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const source = fs.readFileSync('app/javascript/controllers/thumbnail_fetcher_controller.js', 'utf8')
  .replace(/^import .*\n/gm, '').replace('export default class', 'return class')
const Class = new Function('Controller', 'fetch', 'document', source)
function setup(fetch = async () => {}) {
  const controller = new (Class(class {}, fetch, { querySelector: () => ({ content: "csrf-token" }) }))()
  const fields = Object.fromEntries(['apiId', 'externalUrl', 'catalogSelection', 'importSelection', 'author', 'review'].map(key => [key, { value: key, closest: () => ({ style: { removeProperty() {} } }) }]))
  controller.targets = { find: name => fields[name], findAll: name => fields[name] ? [fields[name]] : [] }
  controller.hasImportSelectionTarget = true
  controller.importSelectionTarget = fields.importSelection
  controller.hasImportPreviewTarget = true
  controller.importPreviewTarget = { classList: { add() {} } }
  controller.submitButtonTargets = [{ disabled: false }]
  controller.mediaTypeValue = 'book'
  controller.renderImport = () => {}
  controller.applyOption = () => { throw new Error('stale preview applied') }
  return { controller, fields }
}

test('manual conversion clears every provider identity and retains metadata and personal edits', () => {
  const { controller, fields } = setup()
  controller.clearImport()
  for (const name of ['apiId', 'externalUrl', 'catalogSelection', 'importSelection']) assert.equal(fields[name].value, '')
  assert.equal(fields.author.value, 'author')
  assert.equal(fields.review.value, 'review')
})

test('a detail response arriving after manual conversion cannot restore the imported selection or overwrite edits', async () => {
  let resolve
  const pending = new Promise(done => { resolve = done })
  const { controller, fields } = setup(() => pending)
  const loading = controller.loadImport({ import_selection: 'signed' })
  assert.equal(controller.submitButtonTargets[0].disabled, true)
  controller.clearImport()
  fields.author.value = 'My edit'
  resolve({ ok: true, json: async () => ({ author: 'Provider', import_selection: 'new' }) })
  await loading
  assert.equal(fields.author.value, 'My edit')
  assert.equal(fields.importSelection.value, '')
})

test('failed preview never silently enables an unconfirmed import', async () => {
  const { controller } = setup(async () => ({ ok: false }))
  let message
  controller.renderImport = (_option, text) => { message = text }
  await controller.loadImport({ import_selection: 'signed' })
  assert.match(message, /Unable to load the preview/)
  assert.equal(controller.submitButtonTargets[0].disabled, true)
})

test('missing artwork does not request an empty URL or trigger the global broken-image fallback', () => {
  const { controller } = setup()
  delete controller.applyOption
  controller.previewImgTarget = { style: {} }
  controller.thumbnailUrlTarget = { value: '' }
  controller.placeholderTarget = { style: {} }
  controller.applyOption({ title: 'No cover' })
  assert.match(controller.previewImgTarget.src, /^data:image\/gif/)
  assert.equal(controller.previewImgTarget.style.display, 'none')
  assert.equal(controller.placeholderTarget.style.display, 'block')
})

test('selected detail transport uses a CSRF-protected POST body rather than a long URL', async () => {
  let request
  const { controller } = setup(async (url, options) => { request = { url, options }; return { ok: false } })
  const selection = 'x'.repeat(30_000)
  await controller.loadImport({ import_selection: selection })
  assert.equal(request.url, '/media/import_preview')
  assert.equal(request.options.method, 'POST')
  assert.equal(request.options.headers['X-CSRF-Token'], 'csrf-token')
  assert.equal(JSON.parse(request.options.body).selection, selection)
})
