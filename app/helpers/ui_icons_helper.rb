# frozen_string_literal: true

module UiIconsHelper
  # Local vector artwork keeps the interface consistent across platforms and themes.
  PATHS = {
    'film' => '<rect x="3" y="4" width="18" height="16" rx="3"/><path d="M7 4v16M17 4v16M3 9h4m-4 6h4M17 9h4m-4 6h4"/>',
    'tv' => '<rect x="3" y="5" width="18" height="13" rx="3"/><path d="M8 22h8m-4-4v4"/>',
    'book' => '<path d="M6 3h13v18H6a3 3 0 0 1-3-3V6a3 3 0 0 1 3-3Zm-3 15a3 3 0 0 1 3-3h13M8 7h6"/>',
    'library' => '<rect x="3" y="4" width="5" height="16" rx="1"/><path d="M11 4v16m4-15 4-1 4 15-4 1-4-15ZM3 8h5"/>',
    'disc' => '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="2"/><path d="M7 12a5 5 0 0 ' \
              '1 5-5m0 10a5 5 0 0 0 5-5"/>',
    'gamepad' => '<path d="M7 7h10c2 0 3 2 3.5 4l1 6c.4 3-2 4-4 2l-3-3h-5l-3 3c-2 2-4.4 1-4-2l1-6C4 9 5 ' \
                 '7 7 7Z"/><path d="M6 11v4m-2-2h4m8-2h.01M19 14h.01"/>',
    'archive' => '<rect x="3" y="3" width="18" height="5" rx="1"/><path d="M5 8v13h14V8m-9 4h4"/>',
    'folder' => '<path d="M3 7V5a2 2 0 0 1 2-2h4l3 4h7a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7Z"/>',
    'globe' => '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a18 18 0 0 1 0 18 18 18 0 0 1 0-18Z"/>',
    'search' => '<circle cx="10.5" cy="10.5" r="7.5"/><path d="m16 16 5 5"/>',
    'shopping-bag' => '<path d="M5 7h14l2 14H3L5 7Zm3 0V6a4 4 0 0 1 8 0v1M8 7v4m8-4v4"/>',
    'chevron-down' => '<path d="m6 9 6 6 6-6"/>',
    'wrestling' => '<path d="m3 8 9-4 9 4v10l-9 3-9-3V8Zm0 5 9 4 9-4M3 8l9 4 9-4m-9 4v9"/>',
    'user' => '<circle cx="12" cy="8" r="4"/><path d="M4 21v-2a8 8 0 0 1 16 0v2"/>',
    'bluesky' => '<path d="M12 11C9 5 3 2 3 6v6c0 3 4 4 7 2-6 3-3 8 0 6l2-3 2 3c3 2 6-3 0-6 3 2 7 1 7-2V6c0-4-6-1-9 5Z"/>',
    'mastodon' => '<path d="M7 20c-3-1-4-4-4-9V7c0-5 18-5 18 0v6c0 4-8 5-13 3m-1 4c3 1 6 1 9 0M7 12V7l3 3 2-3 2 3 3-3v5"/>',
    'circle-check' => '<circle cx="12" cy="12" r="9"/><path d="m8 12 3 3 5-6"/>',
    'drama' => '<path d="M3 3c4 2 8 2 12 0v7c0 4-3 6-6 8-3-2-6-4-6-8V3Zm12 5 6-1v8c0 3-2 5-5 7l-4-3M6 ' \
               '8h1m4 0h1m-5 5q2-2 4 0"/>',
    'star' => '<path d="m12 3 2.8 5.7 6.2.9-4.5 4.4 1.1 6.2-5.6-3-5.6 3 1.1-6.2L3 9.6l6.2-.9L12 3Z"/>',
    'pen' => '<path d="m15 4 5 5M4 20l5-1L21 7a2 2 0 0 0-5-5L4 14l-1 7 6-2"/>',
    'heart' => '<path d="M20.5 5.5a5 5 0 0 0-7 0L12 7l-1.5-1.5a5 5 0 0 0-7 7L12 21l8.5-8.5a5 5 0 0 0 0-7Z"/>'
  }.freeze

  def ui_icon(name)
    content_tag(:svg, PATHS.fetch(name.to_s).html_safe,
                class: "ui-icon ui-icon--#{name}", viewBox: '0 0 24 24',
                width: 20, height: 20, fill: 'none', stroke: 'currentColor',
                'stroke-width': 1.65, 'stroke-linecap': 'round', 'stroke-linejoin': 'round',
                'aria-hidden': true, focusable: false)
  end
end
