# Landing mascot artwork

The blog bridge uses the detailed smiling Telly and Facet duo from Library
`libfile_71921a5f1ae8819181b5bd2ed0efbd07` (`Telly and Facet Sticker Duo.png`).
This genuine 1536 × 1024 RGBA source matches the supplied JPEG reference's
waving Telly, microphone, glasses, headphones, and yellow book. The source has
transparent corners; the JPEG reference was not used as an alpha source.

`app/assets/images/brand/telly-facet-duo.webp` preserves that composition,
resized to 768 × 512, stripped of metadata, and encoded at WebP quality 90.
It is 71,208 bytes and retains alpha. The image renders at 240 × 160 with
explicit dimensions, lazy loading, and asynchronous decoding.

At widths up to 720px, solo Facet occupies the first grid row above the hero
copy. Desktop keeps the existing side-by-side composition. The guest landing
browser regression checks 390px, 720px, and 1440px layouts and records
`landing-mascots-*.png` when `UI_QA_DIR` is set.
