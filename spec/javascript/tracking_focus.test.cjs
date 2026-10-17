const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')

test('submission intent restores focus even after Turbo disables and blurs the submitter', async () => {
  let focused = false, rendered = false
  const button = { focus: () => { focused = true } }
  const document = { activeElement: {}, getElementById: () => ({ querySelector: () => button }) }
  const source = fs.readFileSync('app/javascript/controllers/tracking_focus_controller.js', 'utf8')
    .replace(/^import .*\n/gm, '').replace('export default class', 'return class')
  const Class = new Function('Controller', 'document', source)(class {}, document)
  const controller = new Class()
  controller.element = { id: 'in_progress_1', contains: () => false, closest: () => ({ id: 'section' }) }
  const event = { target: { getAttribute: () => 'in_progress_1' }, detail: { render: async () => { rendered = true } } }
  controller.remember()
  controller.retain(event)
  await event.detail.render({})
  assert.equal(rendered, true)
  assert.equal(focused, true)
})
