const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const source = readFileSync('app/javascript/controllers/favorite_shelf_controller.js', 'utf8')
  .replace(/^import .*\n/gm, '').replace('export default class', 'return class')

const imageSource = readFileSync('app/javascript/controllers/shelf_image.js', 'utf8').replace(/export /g, '')
const {shelfCompanion, shelfPublicLink, SHELF_STYLES} = new Function(imageSource + ';return {shelfCompanion,shelfPublicLink,SHELF_STYLES}')()
function fixture() {
  let renders = 0
  const renderOptions = []
  const Controller = new Function('Controller', 'renderShelfImage', 'shelfImageAltText', 'SHELF_THEMES', 'SHELF_STYLES', 'shelfCompanion', 'shelfPublicLink', source)(
    class {}, async (_canvas, options) => { renders++; renderOptions.push(options) }, () => 'Shelf image description', { midnight: {} }, SHELF_STYLES, shelfCompanion, shelfPublicLink
  )
  const instance = Object.create(Controller.prototype)
  instance.imageOptions = () => ({ picks: [], theme: 'midnight' })
  instance.imageTheme = 'midnight'; instance.previewSignatureValue = 'signature'
  instance.previewCategoryValue = 'Movie'; instance.urlValue = '/@owner/shelf?category=Movie'
  instance.ownerValue = true; instance.element = { isConnected: true, querySelectorAll: () => [] }
  instance.applyTheme = () => {}
  instance.statusTarget = { textContent: '' }; instance.altTextTarget = { value: '' }
  instance.canvasTarget = { dataset: {}, setAttribute() {}, closest: () => ({ open: false }), getContext: () => ({ drawImage() {} }) }
  global.document = {
    createElement: () => ({ getContext: () => ({ drawImage() {} }), toBlob: callback => callback(new Blob(['png'])) }),
    querySelector: () => ({ content: 'csrf-test' })
  }
  return { instance, renders: () => renders, renderOptions }
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
  assert.match(instance.statusTarget.textContent, /saved picks are safe/)
})

test('a detached shelf cannot upload the result of a completed render', async () => {
  const { instance } = fixture()
  instance.element.isConnected = false
  global.fetch = () => { throw new Error('Unexpected stale upload') }
  assert.equal(await instance.storePreview(), false)
})


test('published category previews retain the custom identity while using the social landscape format', async()=>{
 const {instance,renderOptions}=fixture()
 delete instance.imageOptions
 instance.picks=[];instance.shelvesValue=[];instance.overviewValue=false;instance.headlineValue="it's finally spooky szn"
 instance.imageStyle={layout:'reading',texture:'clean',companion:'auto'};instance.categoryValue='Books';instance.imageFormat='portrait'
 global.fetch=async()=>({ok:true})
 assert.equal(await instance.storePreview(),true)
 assert.equal(renderOptions[0].headline,"it's finally spooky szn")
 assert.equal(renderOptions[0].category,'Books');assert.equal(renderOptions[0].format,'landscape')
 assert.equal(renderOptions[0].layout,'reading')
})

test('a network failure preserves unsaved appearance and blocks sharing', async () => {
  const { instance } = fixture()
  instance.presentationDirty = true
  instance.imageStyle = { layout: 'mixtape' }
  global.fetch = async () => { throw new Error('Offline') }
  assert.equal(await instance.savePresentation(), false)
  assert.equal(instance.presentationDirty, true)
  assert.match(instance.statusTarget.textContent, /choices are preserved/)
})

test('edits during a pending appearance save stay dirty and block a download', async () => {
  const { instance, renders } = fixture()
  instance.presentationDirty = true
  instance.imageStyle = { layout: 'exhibition' }
  let finish, submitted
  global.fetch = async (_url, options) => {
    submitted = JSON.parse(options.body)
    return new Promise(resolve => { finish = resolve })
  }
  const saving = instance.download()
  instance.imageStyle = { layout: 'collector' }
  finish({ ok: true })
  await saving
  assert.equal(submitted.presentation.layout, 'exhibition')
  assert.equal(instance.presentationDirty, true)
  assert.equal(instance.presentationSaving, false)
  assert.equal(renders(), 0)
  assert.match(instance.statusTarget.textContent, /changed during saving/)
})

test('a second share cannot overtake a pending appearance save', async () => {
  const { instance } = fixture()
  instance.presentationDirty = true
  let finish, calls = 0
  global.fetch = async () => { calls++; return new Promise(resolve => { finish = resolve }) }
  const saving = instance.savePresentation()
  assert.equal(await instance.savePresentation(), false)
  assert.equal(calls, 1)
  finish({ ok: true })
  assert.equal(await saving, true)
  assert.equal(instance.presentationDirty, false)
})

test('a later pick edit is preserved when an older save finishes', async () => {
  const { instance } = fixture()
  instance.picks = [{ id: 1, type: 'Book' }]; instance.dirty = true
  let finish
  global.fetch = async () => new Promise(resolve => { finish = resolve })
  const saving = instance.save()
  instance.picks = [{ id: 2, type: 'Book' }]
  finish({ ok: true, json: async () => ({ preview_signature: 'older-picks' }) })
  assert.equal(await saving, false)
  assert.equal(instance.dirty, true)
  assert.equal(instance.picks[0].id, 2)
  assert.equal(instance.picksSaving, false)
})

test('an external response cannot target a subsequently opened slot or close its dialog', async () => {
  const { instance } = fixture()
  instance.picks = [{ id: 1, type: 'Book' }, { id: 2, type: 'Book' }]
  instance.slot = 0; instance.dialogGeneration = 1
  instance.dialogTarget = { open: true }
  instance.searchTypeTarget = { value: 'book' }
  instance.resultsTarget = { textContent: '' }
  let finish, closes = 0, changes = 0
  instance.close = () => { closes++ }
  instance.changed = () => { changes++ }
  global.fetch = async () => new Promise(resolve => { finish = resolve })
  const adding = instance.selectExternal({ import_selection: 'signed-a' })
  instance.dialogGeneration = 3; instance.slot = 1
  instance.resultsTarget.textContent = 'New search in slot B'
  finish({ ok: true, json: async () => ({ id: 3, type: 'Book', title: 'Old request' }) })
  await adding
  assert.deepEqual(instance.picks.map(pick => pick.id), [1, 2])
  assert.equal(instance.resultsTarget.textContent, 'New search in slot B')
  assert.equal(closes, 0); assert.equal(changes, 0)
})

test('appearance edits during a pick save prevent the following download', async () => {
  const { instance, renders } = fixture()
  instance.picks = [{ id: 1, type: 'Book' }]; instance.dirty = true
  instance.imageStyle = { layout: 'exhibition' }
  let finish
  global.fetch = async () => new Promise(resolve => { finish = resolve })
  const downloading = instance.download()
  await Promise.resolve()
  instance.imageStyle = { layout: 'collector' }; instance.presentationDirty = true
  finish({ ok: true, json: async () => ({ preview_signature: 'saved-picks' }) })
  await downloading
  assert.equal(instance.presentationDirty, true)
  assert.equal(renders(), 0)
})

test('appearance changes during PNG encoding cannot upload mismatched preview metadata', async () => {
  const { instance } = fixture()
  instance.imageStyle = { layout: 'exhibition' }
  let encode
  global.document.createElement = () => ({ toBlob: callback => { encode = callback } })
  global.fetch = () => { throw new Error('Stale preview must not upload') }
  const publishing = instance.storePreview()
  await Promise.resolve()
  instance.imageStyle = { layout: 'collector' }; instance.presentationDirty = true
  encode(new Blob(['png']))
  assert.equal(await publishing, false)
})

test('undo restores the last saved appearance without losing unsaved picks or issuing requests', () => {
  const { instance } = fixture()
  instance.savedAppearance = { theme: 'midnight', style: { layout: 'exhibition', texture: 'paper' } }
  instance.imageTheme = 'gallery'; instance.imageStyle = { layout: 'mixtape', texture: 'stars' }
  instance.presentationDirty = true; instance.dirty = true
  instance.picks = [{ id: 42, type: 'Book' }]
  instance.schedulePreview = () => {}
  global.fetch = () => { throw new Error('Undo must stay local') }
  instance.cancelAppearance()
  assert.equal(instance.presentationDirty, false)
  assert.equal(instance.dirty, true)
  assert.equal(instance.imageTheme, 'midnight')
  assert.deepEqual(instance.imageStyle, { layout: 'exhibition', texture: 'paper' })
  assert.equal(instance.picks[0].id, 42)
})

test('undo during a save is ignored and undo after a concurrent edit restores the saved snapshot', async () => {
  const { instance } = fixture()
  instance.savedAppearance = { theme: 'midnight', style: { layout: 'exhibition' } }
  instance.imageStyle = { layout: 'mixtape' }; instance.presentationDirty = true
  let finish
  global.fetch = () => new Promise(resolve => { finish = resolve })
  const saving = instance.savePresentation()
  instance.cancelAppearance()
  assert.equal(instance.imageStyle.layout, 'mixtape')
  instance.imageStyle.layout = 'collector'
  finish({ ok: true })
  assert.equal(await saving, false)
  instance.schedulePreview = () => {}
  instance.cancelAppearance()
  assert.equal(instance.imageStyle.layout, 'mixtape')
})

test('repeated appearance navigation opens and focuses the panel without duplicate history entries', () => {
  const { instance } = fixture()
  let focus = 0, scroll = 0, pushes = 0, prevented = 0
  const panel = { open: false, scrollIntoView() { scroll++ } }
  const heading = { setAttribute() {}, focus() { focus++ } }
  instance.element.querySelector = selector => selector === '#shelf-appearance-heading' ? heading : panel
  global.window = { location: { hash: '' }, history: { pushState(_state, _title, hash) { pushes++; window.location.hash = hash } } }
  const event = { preventDefault() { prevented++ } }
  instance.showAppearance(event); panel.open = false; instance.showAppearance(event)
  assert.equal(panel.open, true)
  assert.equal(pushes, 1)
  assert.equal(focus, 2)
  assert.equal(scroll, 2)
  assert.equal(prevented, 2)
})


test('visitor export choices never become persistent appearance edits', () => {
  const { instance } = fixture()
  instance.ownerValue = false
  instance.imageStyle = { companion: 'facet' }
  instance.appearanceChanged()
  assert.equal(instance.presentationDirty, undefined)
  assert.equal(instance.statusTarget.textContent, '')
})

test('copy and native share consistently use only the canonical profile', async () => {
 const {instance}=fixture()
 instance.handleValue='owner';instance.publicUrlValue='https://trove.schweg.xyz/@owner/shelf?collection=films&companion=bat'
 instance.imageStyle={companion:'bat'}
 const copied=[],shared=[]
 Object.defineProperty(global,'navigator',{configurable:true,value:{clipboard:{writeText:async url=>copied.push(url)},share:async data=>shared.push(data)}})
 await instance.copyLink();await instance.nativeShare()
 assert.deepEqual(copied,['https://trove.schweg.xyz/@owner'])
 assert.equal(shared[0].url,copied[0])
 delete global.navigator
})

test('public shelf visitors can switch mascots repeatedly without saving owner settings', async () => {
 const {instance}=fixture()
 instance.ownerValue=false;instance.imageStyle={companion:'bat'}
 instance.applyTheme=()=>{};instance.revealPreview=()=>{};instance.schedulePreview=()=>{}
 global.fetch=()=>{throw Error('Visitors must never save appearance')}
 for(const value of ['telly','facet','none','bat','telly']){
  instance.customize({target:{name:'companion',value}})
  assert.equal(instance.imageStyle.companion,value)
  assert.ok(!instance.presentationDirty)
  assert.equal(await instance.savePresentation(),true)
 }
})
