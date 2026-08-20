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

## 2026-06-21 - [ARIA Selection State Announcement for Custom Grid Buttons]
**Learning:** Dynamic custom button elements (such as cover thumbnail result cards) that use `role="button"` require `aria-pressed="true"/"false"` attributes to inform screen reader users of their current selection state when toggled.
**Action:** Set `aria-pressed="false"` upon element creation and dynamically toggle `aria-pressed="true"` on the selected option card while clearing it on unselected cards.
