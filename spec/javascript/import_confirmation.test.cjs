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

function connectWithTitle({ title = '', selection = false, errors = false } = {}) {
  const { controller } = setup()
  const calls = []
  const form = { addEventListener() {} }
  controller.element = { dataset: {}, querySelector: selector => selector === 'form' ? form : errors ? {} : null }
  controller.titleInputTarget = { value: title, closest: () => ({ parentElement: {} }) }
  controller.thumbnailUrlTarget = { value: '' }
  controller.releaseYearTargets = []
  controller.hasImportSelectionTarget = false
  controller.hasSelectionValue = selection
  controller.selectionValue = { import_selection: 'signed-selection' }
  controller.goToSearch = () => { calls.push('search stage') }
  controller.showDetailsStage = () => { calls.push('details stage') }
  controller.search = () => { calls.push('resume query') }
  controller.selectOption = (option, explicit) => { calls.push([option.import_selection, explicit]) }
  controller.connect()
  assert.equal(controller.element.dataset.connected, 'true')
  return calls
}

test('connection resumes a title entered before the search controller was ready', () => {
  assert.deepEqual(connectWithTitle({ title: 'An early query' }), ['search stage', 'resume query'])
})

test('connection leaves an empty query idle', () => {
  assert.deepEqual(connectWithTitle({ title: '   ' }), ['search stage'])
})

test('connection honors a signed selection without starting a competing title search', () => {
  assert.deepEqual(connectWithTitle({ title: 'Selected title', selection: true }),
    ['search stage', ['signed-selection', true]])
})

test('connection preserves validation errors instead of restarting provider search', () => {
  assert.deepEqual(connectWithTitle({ title: 'Retained edits', errors: true }), ['details stage'])
})
