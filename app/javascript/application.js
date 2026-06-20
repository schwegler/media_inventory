import "@hotwired/turbo-rails"
import "controllers"

// Ensure body scroll is restored after Turbo navigations (especially when navigating away from a modal)
document.addEventListener("turbo:load", () => {
  document.body.style.overflow = ""
  document.documentElement.style.overflow = ""
})

// Also clean up before caching to prevent restoring a locked page
document.addEventListener("turbo:before-cache", () => {
  document.body.style.overflow = ""
  document.documentElement.style.overflow = ""
})
