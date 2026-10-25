# frozen_string_literal: true

# Passive input diagnostics for CI artifacts. Do not record typed text, retry
# actions, change focus, or replace native browser input with JavaScript clicks.
module BrowserInputTrace
  SCRIPT = <<~JS
    window.troveBrowserFailureEvents = [];
    const describe = node => node instanceof Element ? { tag: node.tagName, id: node.id,
      text: node.matches('a, button, summary') ? node.textContent?.trim().slice(0, 80) : undefined,
      class: node.getAttribute('class'), label: node.getAttribute('aria-label'), href: node.getAttribute('href') }
      : { tag: node === window ? 'WINDOW' : node?.nodeName };
    const record = entry => {
      window.troveBrowserFailureEvents.push(entry);
      if (window.troveBrowserFailureEvents.length > 200) window.troveBrowserFailureEvents.shift();
    };
    for (const type of ['pointerover', 'pointerout', 'pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click', 'focusin', 'keydown']) {
      document.addEventListener(type, event => {
        if (type === 'keydown' && !['Enter', 'Escape', 'Tab'].includes(event.key)) return;
        record({ type, at: performance.now(), target: describe(event.target), key: event.key,
          interactive: describe(event.target.closest?.('a, button, input, select, summary, label')),
          trusted: event.isTrusted, x: event.clientX, y: event.clientY, scroll: [scrollX, scrollY],
          ctrl: event.ctrlKey, shift: event.shiftKey, alt: event.altKey, meta: event.metaKey,
          focused: document.hasFocus(), visibility: document.visibilityState });
      }, { capture: true, passive: true });
    }
    for (const type of ['scroll', 'resize', 'focus', 'blur']) {
      addEventListener(type, () => record({ type, at: performance.now(), scroll: [scrollX, scrollY],
        viewport: [innerWidth, innerHeight], focused: document.hasFocus(), visibility: document.visibilityState }));
    }
    new PerformanceObserver(list => list.getEntries().forEach(entry => record({ type: 'layout-shift',
      at: entry.startTime, value: entry.value, recentInput: entry.hadRecentInput,
      sources: entry.sources.map(source => ({ node: describe(source.node),
        previous: [source.previousRect.x, source.previousRect.y, source.previousRect.width, source.previousRect.height],
        current: [source.currentRect.x, source.currentRect.y, source.currentRect.width, source.currentRect.height] }))
    }))).observe({ type: 'layout-shift', buffered: true });
  JS

  def self.install(browser)
    browser.execute_script('window.troveBrowserFailureEvents = []')
    browser.execute_cdp('Page.addScriptToEvaluateOnNewDocument', source: SCRIPT).fetch('identifier')
  end

  def self.remove(browser, identifier)
    browser.execute_cdp('Page.removeScriptToEvaluateOnNewDocument', identifier: identifier) if browser && identifier
  rescue StandardError => e
    warn "Browser input-trace cleanup could not finish: #{e.class}: #{e.message}"
  end
end
