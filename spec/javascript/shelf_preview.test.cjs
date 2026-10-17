const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const source = readFileSync('app/javascript/controllers/favorite_shelf_controller.js', 'utf8')
  .replace(/^import .*\n/gm, '').replace('export default class', 'return class')

function fixture() {
  let renders = 0
  const Controller = new Function('Controller', 'renderShelfImage', 'shelfImageAltText', 'SHELF_THEMES', source)(
    class {}, async () => { renders++ }, () => 'Shelf image description', { midnight: {} }
  )
  const instance = Object.create(Controller.prototype)
  instance.imageOptions = () => ({ picks: [], theme: 'midnight' })
  instance.imageTheme = 'midnight'; instance.previewSignatureValue = 'signature'
  instance.previewCategoryValue = 'Movie'; instance.urlValue = '/@owner/shelf?category=Movie'
  instance.ownerValue = true; instance.element = { isConnected: true }
  instance.statusTarget = { textContent: '' }; instance.altTextTarget = { value: '' }
  instance.canvasTarget = { setAttribute() {}, closest: () => ({ open: false }), getContext: () => ({ drawImage() {} }) }
  global.document = {
    createElement: () => ({ getContext: () => ({ drawImage() {} }), toBlob: callback => callback(new Blob(['png'])) }),
    querySelector: () => ({ content: 'csrf-test' })
  }
  return { instance, renders: () => renders }
}

test('browsing and closed previews do no canvas or upload work', async () => {
  const { instance, renders } = fixture()
  instance.hasSlotsTarget = false
  global.fetch = () => { throw new Error('Unexpected upload') }
  instance.render()
  assert.equal(renders(), 0)
  assert.equal(instance.altTextTarget.value, 'Shelf image description')
  await instance.preview()
  assert.equal(renders(), 1)
})

test('an explicit publish carries CSRF and category/signature and reuses its result', async () => {
  const { instance, renders } = fixture()
  let uploads = 0
  global.fetch = async (url, options) => {
    uploads++
    assert.equal(url, instance.urlValue)
    assert.equal(options.method, 'PATCH')
    assert.equal(options.headers['X-CSRF-Token'], 'csrf-test')
    assert.equal(options.body.get('preview_signature'), 'signature')
    assert.equal(options.body.get('preview_category'), 'Movie')
    return { ok: true }
  }
  assert.equal(await instance.storePreview(), true)
  assert.equal(await instance.storePreview(), true)
  assert.equal(uploads, 1)
  assert.equal(renders(), 1)
})

test('unsaved changes prevent publication and failure restores an actionable control', async () => {
  const { instance } = fixture()
  let calls = 0
  instance.storePreview = async () => { calls++; throw new Error('Offline') }
  const button = { disabled: false, setAttribute() {}, removeAttribute() {} }
  instance.dirty = true
  await instance.publishPreview({ currentTarget: button })
  assert.equal(calls, 0)
  instance.dirty = false
  await instance.publishPreview({ currentTarget: button })
  assert.equal(calls, 1)
  assert.equal(button.disabled, false)
  assert.match(instance.statusTarget.textContent, /saved favorites are safe/)
})

test('a detached shelf cannot upload the result of a completed render', async () => {
  const { instance } = fixture()
  instance.element.isConnected = false
  global.fetch = () => { throw new Error('Unexpected stale upload') }
  assert.equal(await instance.storePreview(), false)
})
