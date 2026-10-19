export const SHELF_THEMES = {
  midnight_feature: { label: 'Midnight Feature', bg: '#0b090b', text: '#f5e9d8', muted: '#c5aba7', accent: '#ff5964', surface: '#211416', line: '#ff59644d' },
  halloween: { bg: '#140f1b', text: '#fff0d6', muted: '#efc196', accent: '#ffbd65', surface: '#302136', line: '#ffbd6540' },
  telly: { bg: '#e6f4ff', text: '#102a49', muted: '#3c5871', accent: '#075c9c', surface: '#c7e4f7', line: '#102a4930' },
  facet: { bg: '#eee5fa', text: '#291e40', muted: '#594568', accent: '#6330a6', surface: '#ddc9f0', line: '#291e4030' },
  midnight: { bg: '#101117', text: '#f6f3eb', muted: '#aaaab1', accent: '#dfff8e', surface: '#202127', line: '#ffffff26' },
  gallery: { bg: '#f5f2eb', text: '#22221f', muted: '#66665e', accent: '#415338', surface: '#e5e1d7', line: '#22221f30' },
  electric: { bg: '#181235', text: '#fff4f6', muted: '#bcb0d7', accent: '#ff9ccf', surface: '#30234f', line: '#fff4f630' }
}

export function shelfImageHeading(headline) {
  return typeof headline === "string" && headline.trim() ? headline.trim() : "The things I keep."
}

export function shelfImageAltText({ picks, shelves, overview, theme, format, handle, category, headline, layout = "exhibition", texture = "clean", companion = "auto" }) {
  const source = overview ? shelves : [{ label: category, picks }]
  const heading = shelfImageHeading(headline)
  const description = source.map(shelf => {
    const titles = shelf.picks.slice(0, 5).map((pick, index) => `${index + 1}. ${pick.title || 'Untitled selection'}`)
    return `${shelf.label}: ${titles.length ? titles.join('; ') : 'No selections yet'}.`
  }).join('\n')
  return `${format === 'portrait' ? 'Portrait' : 'Landscape'} Trove share image for @${handle}’s Shelf in the ${SHELF_THEMES[theme]?.label || theme} theme. Heading: “${heading}”. ${overview ? "Shelf overview" : `Category: ${category || "Selections"}`}. ${layout} layout, ${texture} texture, ${companion} companion. Covers appear in selected order.\n${description}`
}

async function cover(pick) {
  if (!pick?.cover) return null
  return new Promise(resolve => {
    const image = new Image()
    const timer = setTimeout(() => { image.src = ''; resolve(null) }, 8000)
    image.onload = () => { clearTimeout(timer); resolve(image) }
    image.onerror = () => { clearTimeout(timer); resolve(null) }
    // Stored artwork is proxied through the app, so downloads remain origin-clean.
    image.src = pick.cover
  })
}

function text(ctx, value, x, y, width, size, lines = 2, family = "sans-serif") {
  ctx.font = `${size}px ${family}`
  const words = String(value ?? "").trim().split(/\s+/)
  for (let line = 0; line < lines && words.length; line++) {
    let result = words.shift()
    while (words.length && ctx.measureText(`${result} ${words[0]}`).width <= width) result += ` ${words.shift()}`
    if (line === lines - 1 && words.length) result += '…'
    const characters = typeof Intl.Segmenter === "function" ? Array.from(new Intl.Segmenter(undefined, { granularity: "grapheme" }).segment(result), part => part.segment) : Array.from(result)
    while (ctx.measureText(result).width > width && characters.length > 1) { characters.pop(); result = `${characters.join("").replace(/…$/, "")}…` }
    ctx.fillText(result, x, y + line * size * 1.3)
  }
}

function artwork(ctx, image, x, y, width, height, theme, rank, pick) {
  ctx.fillStyle = theme.surface; ctx.fillRect(x, y, width, height)
  if (image) {
    const scale = (pick?.type === "Album" ? Math.min : Math.max)(width / image.width, height / image.height)
    ctx.save(); ctx.beginPath(); ctx.rect(x, y, width, height); ctx.clip()
    ctx.drawImage(image, x + (width - image.width * scale) / 2, y + (height - image.height * scale) / 2, image.width * scale, image.height * scale)
    ctx.restore()
  } else {
    ctx.fillStyle = theme.muted; ctx.font = `${Math.min(width / 3, 40)}px Georgia`; ctx.fillText(String(rank).padStart(2, '0'), x + 12, y + 40)
  }
  ctx.strokeStyle = theme.line; ctx.strokeRect(x, y, width, height)
}

export const SHELF_STYLES = { layout: ["exhibition", "reading", "collector"], texture: ["clean", "paper", "stars"], companion: ["auto", "none", "telly", "facet", "bat"] }

// Geometry is deterministic, including sparse shelves. Labels stay inside a 72px safe edge.
export function portraitShelfLayout(count, layout = "exhibition") {
  const n = Math.min(5, Math.max(0, count))
  return Array.from({ length: n }, (_, i) => {
    if (layout === "reading") {
      const height = n === 1 ? 660 : n === 2 ? 360 : n === 3 ? 280 : n === 4 ? 200 : 164
      const width = height * 2 / 3, y = n === 1 ? 600 : (n === 2 ? 600 : 540) + i * (n === 2 ? 460 : n === 3 ? 330 : n === 4 ? 240 : 196)
      return { x: 72, y, width, height, labelX: 112 + width, labelY: y + (n === 1 ? 170 : 65), labelWidth: 896 - width, font: n === 1 ? 48 : 34, labelLines: 3 }
    }
    if (layout === "collector") {
      const featured = i === 0, width = n === 1 ? 440 : featured ? 420 : 200
      const x = n === 1 ? 320 : featured ? 72 : 568 + (n > 3 ? ((i - 1) % 2) * 240 : 0)
      const y = 560 + (featured ? 0 : Math.floor((i - 1) / (n > 3 ? 2 : 1)) * 335)
      return { x, y, width, height: width * 1.5, labelX: 72, labelY: 1270 + i * 58, labelWidth: 936, font: n === 1 ? 38 : 34, labelLines: 1 }
    }
    const cols = Math.min(3, n), width = n === 1 ? 440 : n === 2 ? 340 : n === 3 ? 272 : 220
    const row = Math.floor(i / cols), inRow = Math.min(cols, n - row * cols), gap = n === 3 ? 60 : 40
    const x = (1080 - (inRow * width + (inRow - 1) * gap)) / 2 + (i % cols) * (width + gap)
    const y = n === 1 ? 600 : n === 2 ? 690 : n === 3 ? 760 : 560 + row * 490
    return { x, y, width, height: width * 1.5, labelX: n === 1 ? 72 : x, labelY: y + width * 1.5 + 48, labelWidth: n === 1 ? 936 : width, font: n === 1 ? 42 : 32, labelLines: n === 1 ? 2 : 3 }
  })
}

async function companionImage(name, theme, assets) {
  const selected = name === "auto" ? (theme === "halloween" ? "bat" : ["telly", "facet"].includes(theme) ? theme : "none") : name
  if (selected === "none" || !assets?.[selected]) return null
  const image = await cover({ cover: assets[selected] })
  return image ? { image, selected } : null
}

export async function renderShelfImage(canvas, { picks = [], shelves = [], overview, theme: themeName, format, handle, category, headline, layout = "exhibition", texture = "clean", companion = "auto", assets = {}, siteHost = window.location.host }) {
  const portrait = format === "portrait", theme = SHELF_THEMES[themeName] || SHELF_THEMES.midnight
  const source = overview ? shelves : [{ label: category, picks }]
  const [images, mascot] = await Promise.all([
    Promise.all(source.map(shelf => Promise.all(shelf.picks.slice(0, 5).map(cover)))),
    companionImage(companion, themeName, assets)
  ])
  const output = document.createElement("canvas")
  output.width = portrait ? 1080 : 1200; output.height = portrait ? 1920 : 630
  const ctx = output.getContext("2d"), w = output.width, h = output.height, edge = 72
  ctx.fillStyle = theme.bg; ctx.fillRect(0, 0, w, h)
  const horror = themeName === "midnight_feature"
  if (horror) {
    // Static film grain is generated only when an image is requested; never animated.
    ctx.fillStyle = "#ffffff0a"
    for (let i = 0; i < 1800; i++) ctx.fillRect((i * 71 + 19) % w, (i * 137 + 31) % h, 1, 1)
    ctx.fillStyle = theme.accent
    const ruleY = portrait ? 518 : 187
    for (let x = edge; x < w - edge; x += 31) ctx.fillRect(x, ruleY, Math.min(27, w - edge - x), 2)
  }
  if (texture !== "clean") {
    ctx.fillStyle = theme.line
    const step = texture === "paper" ? 24 : 78
    for (let y = 20; y < h; y += step) for (let x = 20; x < w; x += step) {
      ctx.beginPath(); ctx.arc(x, y, texture === "paper" ? 0.7 : 1.7, 0, Math.PI * 2); ctx.fill()
    }
  }
  ctx.fillStyle = theme.accent; ctx.font = `${portrait ? 28 : 20}px sans-serif`; ctx.fillText(horror ? "TROVE / MIDNIGHT FEATURE" : "TROVE / THE PERSONAL SHELF", edge, portrait ? 284 : 55)
  ctx.fillStyle = theme.text
  const heading = shelfImageHeading(headline)
  text(ctx, heading, edge, portrait ? 350 : 110, portrait ? 780 : 936, portrait ? 58 : 36, 2, horror ? 'Impact, "Arial Narrow", sans-serif' : "Georgia")
  ctx.fillStyle = theme.muted
  text(ctx, `@${handle}’s Shelf · ${overview ? "All selections" : category || "Selections"}`, edge, portrait ? 496 : 185, portrait ? 780 : 1056, portrait ? 26 : 19, 1)
  if (mascot) {
    const image = mascot.image, height = portrait ? 128 : 86, width = height * image.width / image.height
    ctx.drawImage(image, w - edge - width, portrait ? 270 : 20, width, height)
  }
  if (overview) {
    source.forEach((shelf, index) => {
      const x = portrait ? edge : edge + (index % 2) * 550
      const y = portrait ? 548 + index * 140 : 205 + Math.floor(index / 2) * 81
      ctx.fillStyle = theme.text; text(ctx, shelf.label, x, y + 28, portrait ? 156 : 96, portrait ? 26 : 17, 2)
      const count = Math.min(5, shelf.picks.length), width = portrait ? 78 : 57, height = portrait ? 117 : 68
      if (!count) { ctx.fillStyle = theme.muted; text(ctx, "A little room for the next discovery.", x + (portrait ? 180 : 110), y + 38, portrait ? 710 : 390, portrait ? 23 : 15, 1) }
      for (let i = 0; i < count; i++) artwork(ctx, images[index][i], x + (portrait ? 180 : 110) + i * (width + (portrait ? 68 : 22)), y, width, height, theme, i + 1, shelf.picks[i])
    })
  } else if (portrait) {
    portraitShelfLayout(picks.length, layout).forEach((box, i) => {
      artwork(ctx, images[0][i], box.x, box.y, box.width, box.height, theme, i + 1, picks[i])
      ctx.fillStyle = theme.text; text(ctx, `${String(i + 1).padStart(2, "0")} · ${picks[i].title || "Untitled selection"}`, box.labelX, box.labelY, box.labelWidth, box.font, box.labelLines)
    })
    if (!picks.length) { ctx.fillStyle = theme.text; text(ctx, "A shelf taking shape.", edge, 840, 936, 64, 2); ctx.fillStyle = theme.muted; text(ctx, "Room for your next favorite.", edge, 970, 936, 32, 2) }
  } else {
    const n = Math.min(5, picks.length), width = 176, gap = 36, start = (w - (n * width + Math.max(0, n - 1) * gap)) / 2
    for (let i = 0; i < n; i++) {
      const x = start + i * (width + gap)
      artwork(ctx, images[0][i], x, 210, width, 230, theme, i + 1, picks[i])
      ctx.fillStyle = theme.text; text(ctx, `${i + 1}. ${picks[i].title || "Untitled selection"}`, x, 474, width, 19, 2)
    }
    if (!n) { ctx.fillStyle = theme.muted; text(ctx, "A shelf taking shape. Room for your next favorite.", edge, 320, 1056, 32, 2) }
  }
  ctx.strokeStyle = theme.line; ctx.beginPath(); ctx.moveTo(edge, h - (portrait ? 330 : 100)); ctx.lineTo(w - edge, h - (portrait ? 330 : 100)); ctx.stroke()
  ctx.fillStyle = theme.muted; text(ctx, `${siteHost}/@${handle}`, edge, h - (portrait ? 280 : 49), w - edge * 2, portrait ? 26 : 18, 1)
  canvas.width = w; canvas.height = h; canvas.getContext("2d").drawImage(output, 0, 0)
}
