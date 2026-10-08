import "@hotwired/turbo-rails"
import "controllers"

// Ensure body scroll is restored after Turbo navigations (especially when navigating away from a modal)
document.addEventListener("turbo:load", () => {
  document.body.style.overflow = ""
  document.documentElement.style.overflow = ""
})

// Also clean up before caching to prevent restoring a locked page
document.addEventListener("turbo:before-cache", () => {
  document.querySelectorAll("[data-modal-inert]").forEach(el => { el.inert = false; delete el.dataset.modalInert })
  document.body.style.overflow = ""
  document.documentElement.style.overflow = ""
})

// Capture the real trigger before Turbo replaces modal frame contents.
document.addEventListener("click", event => {
  const link = event.target.closest('[data-turbo-frame="modal"]')
  if (link) window.troveModalOpener = link
})

// Turbo replaces the body, not <html>. Apply server-persisted preferences before each render.
// The initial response already includes these tokens on <html>, so no localStorage race or theme flash.
document.addEventListener("turbo:before-render", event => {
  const preferences = event.detail.newBody.dataset.uiPreferences
  if (!preferences) return
  const values = JSON.parse(preferences)
  if (Object.entries(values).some(([key, value]) => document.documentElement.dataset[key] !== value)) window.Turbo?.cache.clear()
  Object.assign(document.documentElement.dataset, values)
})
