# Artwork viewer

Covers and gallery artwork use the same native dialog. The panel fits the image rather than filling a wide rectangle; portrait and landscape images keep their complete aspect ratio within the available viewport. The toolbar uses Trove's light/dark tokens, a short artwork caption, a 44px close control and a full-size link that opens the original image in a separate tab. Small screens wrap the toolbar and leave room for safe areas.

A loading message is replaced by the image after load. If the image fails, the viewer shows one readable error message and keeps the full-size link available. The page artwork fallback does not add another placeholder inside the dialog. No artwork, original URLs or image features are replaced; the previous viewer had no in-dialog zoom controls.

The native modal keeps the background inert. Tab/Shift+Tab wrap between controls; Escape, Close and the backdrop dismiss the viewer. Closing restores focus to the original artwork without scrolling it into a new position. Background scrolling is locked only while open. Turbo navigation/cache, browser Back/Forward and controller disconnection remove the dialog and restore scroll styles so no stale modal is cached.

## Validation

`spec/system/artwork_lightbox_system_spec.rb` covers portrait and landscape fitting in light/dark at 320, 768 and 1440px, loading/error states at the same widths, an actual failed image request, full-size access in a new tab, keyboard containment, focus restoration, repeated open/close, backdrop dismissal and Back/Forward. It uses existing synthetic image fixtures. CI retains screenshots through the existing responsive UI artifact.
