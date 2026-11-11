const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const source = readFileSync('app/javascript/controllers/favorite_shelf_controller.js', 'utf8')
  .replace(/^import .*\n/gm, '').replace('export default class', 'return class')

function fixture() {
  const Controller = new Function('Controller', source)(class {})
  const instance = Object.create(Controller.prototype)
  instance.ownerValue = true
  instance.savedPicks = [{ id: 1, type: 'Movie', title: 'First', cover: '/first.jpg' }, { id: 2, type: 'Book', title: 'Second' }]
  instance.picks = instance.savedPicks.map(pick => ({ ...pick }))
  instance.statusTarget = { textContent: '' }
  instance.hasSelectionStatusTarget = true
  instance.selectionStatusTarget = { textContent: '' }
  const save = { disabled: false }, undo = { disabled: true }
  instance.element = { querySelectorAll: selector => selector === '[data-selection-save]' ? [save] : selector === '[data-selection-undo]' ? [undo] : [] }
  instance.render = () => instance.updateSelectionControls()
  global.document = { querySelector: () => ({ content: 'csrf-test' }) }
  return { instance, save, undo }
}

test('undo restores order and cover metadata, preserves appearance, and never sends a request', () => {
  const { instance, undo } = fixture()
  instance.imageStyle = { companion: 'facet' }; instance.presentationDirty = true
  instance.picks.reverse(); instance.picks.pop(); instance.changed()
  assert.equal(undo.disabled, false)
  global.fetch = () => { throw new Error('Undo must stay local') }
  instance.undoSelections()
  assert.deepEqual(instance.picks, instance.savedPicks)
  assert.notEqual(instance.picks[0], instance.savedPicks[0])
  assert.equal(instance.dirty, false)
  assert.equal(undo.disabled, true)
  assert.equal(instance.presentationDirty, true)
  assert.equal(instance.imageStyle.companion, 'facet')
  assert.match(instance.selectionStatusTarget.textContent, /undone/)
  instance.undoSelections()
  assert.deepEqual(instance.picks.map(pick => pick.id), [1, 2])
})

test('manually restoring the saved order clears the unsaved state', () => {
  const { instance } = fixture()
  instance.picks.reverse(); instance.changed()
  assert.equal(instance.dirty, true)
  instance.picks.reverse(); instance.changed()
  assert.equal(instance.dirty, false)
  assert.match(instance.selectionStatusTarget.textContent, /No unsaved/)
})

test('a failed save preserves the draft and original undo baseline', async () => {
  const { instance, save, undo } = fixture()
  instance.picks.shift(); instance.changed()
  global.fetch = async () => { throw new Error('Offline; retry saving.') }
  assert.equal(await instance.save(), false)
  assert.equal(instance.dirty, true)
  assert.equal(save.disabled, false)
  assert.equal(undo.disabled, false)
  assert.match(instance.selectionStatusTarget.textContent, /Offline/)
  instance.undoSelections()
  assert.deepEqual(instance.picks.map(pick => pick.id), [1, 2])
})

test('undo waits for a pending save, then uses the acknowledged snapshot if later edits remain', async () => {
  const { instance, save, undo } = fixture()
  instance.picks.shift(); instance.changed()
  let finish, calls = 0
  global.fetch = () => { calls++; return new Promise(resolve => { finish = resolve }) }
  const saving = instance.save()
  assert.equal(save.disabled, true)
  assert.equal(undo.disabled, true)
  instance.undoSelections()
  assert.deepEqual(instance.picks.map(pick => pick.id), [2])
  assert.equal(await instance.save(), false)
  assert.equal(calls, 1)
  instance.picks.push({ id: 3, type: 'Movie', title: 'Third' }); instance.changed()
  finish({ ok: true, json: async () => ({ preview_signature: 'updated', shelf_version: 'version' }) })
  assert.equal(await saving, false)
  assert.equal(instance.dirty, true)
  instance.undoSelections()
  assert.deepEqual(instance.picks.map(pick => pick.id), [2])
  assert.equal(instance.editVersionValue, 'version')
})

test('successful saves replace the undo baseline and public visitors cannot undo', async () => {
  const { instance } = fixture()
  instance.picks.shift(); instance.changed()
  global.fetch = async () => ({ ok: true, json: async () => ({ preview_signature: 'saved' }) })
  assert.equal(await instance.save(), true)
  instance.picks = []; instance.changed()
  instance.ownerValue = false
  instance.undoSelections()
  assert.equal(instance.picks.length, 0)
  instance.ownerValue = true
  instance.undoSelections()
  assert.deepEqual(instance.picks.map(pick => pick.id), [2])
})
