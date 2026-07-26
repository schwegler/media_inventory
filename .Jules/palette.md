## 2025-05-15 - [Stimulus Test Synchronization]
**Learning:** System tests in this environment are highly sensitive to race conditions where Capybara attempts to interact with elements before their associated Stimulus controllers have fully connected and initialized (e.g., setting up event listeners or initial ARIA states).
**Action:** Implement a `data-connected="true"` attribute in the Stimulus `connect()` method and use `expect(page).to have_css('[data-connected="true"]')` in system tests before interacting with Stimulus-powered components to ensure reliable synchronization.

## 2026-06-19 - [Focus Management in Multi-stage Modals]
**Learning:** In multi-stage modals where stages are toggled via visibility classes, keyboard focus is often lost or remains on hidden elements, breaking the navigation flow.
**Action:** Implement explicit focus management during stage transitions by targeting the most logical next interactive element (e.g., a "Back" button or the primary input) and using a short timeout to ensure the element is focusable after visibility changes.

## 2026-06-20 - [Focus Management in Keyboard-driven Dropdowns]
**Learning:** For users navigating via keyboard, closing a dropdown with the Escape key should not only hide the menu but also return focus to the triggering element to maintain a logical tab order and prevent focus loss to the document body.
**Action:** Implement a `keydown` listener in dropdown controllers that specifically checks for `Escape`, hides the menu, and explicitly calls `.focus()` on the `buttonTarget`.

## 2025-05-16 - [Skip to Content Link for Keyboard Accessibility]
**Learning:** For keyboard and screen-reader users, navigating through repetitive header links on every page load is tedious. A "Skip to Content" link is a critical foundational UX improvement for accessibility.
**Action:** Always include a `.skip-link` as the first element in the `<body>` that targets the `<main>` content area with an ID like `#main-content`, ensuring it is visually hidden until it receives focus.

## 2026-07-26 - [Manual Alert Dismissal for Accessibility and Control]
**Learning:** For temporary alert notifications that fade out automatically, users must be given manual control to dismiss them instantly. Supporting keyboard accessibility means the dismiss button needs an explicit focus-visible state and an `aria-label`. Additionally, the Stimulus controller's dismiss action must safely handle an optional event parameter to prevent default actions across different triggers.
**Action:** Always include a `<button type="button" class="alert-dismiss" data-action="click->flash#dismiss" aria-label="Dismiss alert">` in flash alerts, style it with focus-visible rings (e.g., using `--accent-gold`), and implement `dismiss(event = null) { if (event) event.preventDefault(); ... }` in `flash_controller.js`.
