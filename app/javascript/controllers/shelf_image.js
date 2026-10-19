export const SHELF_THEMES = {
  midnight_feature: { label: 'Midnight Feature', bg: '#0b090b', text: '#f5e9d8', muted: '#c5aba7', accent: '#ff5964', surface: '#211416', line: '#ff59644d' },
  everyday: { bg: '#f8f4eb', text: '#262724', muted: '#595e53', accent: '#3d573f', surface: '#e9e5db', line: '#26272430' },
  christmas: { bg: '#faf2e2', text: '#183d32', muted: '#526154', accent: '#9b283c', surface: '#e6ddc9', line: '#183d3230' },
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
  const source = overview ? shelves.filter(shelf => shelf.picks.length) : [{ label: category, picks }]
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
    image.crossOrigin = "anonymous"
    image.src = pick.cover
  })
}

function text(ctx, value, x, y, width, size, lines = 2, family = '"Instrument Sans", sans-serif', weight = 400) {
  ctx.font = `${weight} ${size}px ${family}`
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
  if (image) {
    const scale = Math.min(width / image.width, height / image.height)
    const w = image.width * scale, h = image.height * scale
    const left = x + (width - w) / 2, top = y + (height - h) / 2
    ctx.save()
    ctx.shadowColor = '#00000038'; ctx.shadowBlur = 20; ctx.shadowOffsetY = 10
    ctx.fillStyle = theme.surface; ctx.fillRect(left - 6, top - 6, w + 12, h + 12)
    ctx.restore()
    ctx.drawImage(image, left, top, w, h)
    ctx.strokeStyle = theme.line; ctx.strokeRect(left, top, w, h)
  } else {
    ctx.fillStyle = theme.surface; ctx.fillRect(x, y, width, height)
    ctx.fillStyle = theme.muted; ctx.font = '32px Georgia'; ctx.fillText(String(rank).padStart(2, '0'), x + 16, y + 48)
    ctx.strokeStyle = theme.line; ctx.strokeRect(x, y, width, height)
  }
}

export const SHELF_STYLES = { layout: ["exhibition", "reading", "collector", "mixtape"], texture: ["clean", "paper", "stars"], companion: ["auto", "none", "telly", "facet", "bat"] }

// Geometry is deterministic, including sparse shelves. Labels stay inside a 72px safe edge.
export function portraitShelfLayout(count, layout = "exhibition") {
  const n = Math.min(5, Math.max(0, count))
  return Array.from({ length: n }, (_, i) => {
    if (layout === "reading") {
      const height = n === 1 ? 660 : n === 2 ? 360 : n === 3 ? 280 : n === 4 ? 200 : 164
      const width = height * 2 / 3, y = n === 1 ? 600 : (n === 2 ? 600 : 540) + i * (n === 2 ? 460 : n === 3 ? 330 : n === 4 ? 240 : 196)
      return { x: 72, y, width, height, labelX: 112 + width, labelY: y + (n === 1 ? 170 : 65), labelWidth: 896 - width, font: n === 1 ? 48 : 34, labelLines: 3 }
    }
    if (layout === "collector" && n > 1) {
      if (i === 0) return { x: 260, y: 550, width: 560, height: 520, labelX: 72, labelY: 1106, labelWidth: 936, font: 38, labelLines: 1 }
      const columns = n - 1, width = Math.min(250, (936 - (columns - 1) * 32) / columns)
      const left = (1080 - columns * width - (columns - 1) * 32) / 2
      return { x: left + (i - 1) * (width + 32), y: 1210, width, height: 220, labelX: left + (i - 1) * (width + 32), labelY: 1462, labelWidth: width, font: 27, labelLines: 3 }
    }
    if (layout === "mixtape" && n >= 3) {
      if (i < 2) return { x: i === 0 ? 104 : 600, y: 560, width: i === 0 ? 400 : 300, height: 400, labelX: i === 0 ? 90 : 570, labelY: 1000, labelWidth: i === 0 ? 440 : 360, font: 30, labelLines: 2 }
      const columns = n - 2, width = 260, left = (1080 - columns * width - (columns - 1) * 61) / 2
      return { x: left + (i - 2) * 321, y: 1120, width, height: 270, labelX: left + (i - 2) * 321, labelY: 1435, labelWidth: width, font: 28, labelLines: 3 }
    }
    if (n >= 4) {
      const topCount = n === 5 ? 3 : 2, bottom = i >= topCount, columns = bottom ? n - topCount : topCount
      const width = columns === 3 ? 250 : 310, gap = columns === 3 ? 72 : 50
      const left = (1080 - columns * width - (columns - 1) * gap) / 2, column = bottom ? i - topCount : i
      return { x: left + column * (width + gap), y: bottom ? 1080 : 560, width, height: 325, labelX: left + column * (width + gap), labelY: bottom ? 1442 : 922, labelWidth: width, font: 28, labelLines: 3 }
    }
    const width = n === 1 ? 520 : n === 2 ? 360 : 260, gap = 44
    const left = (1080 - n * width - (n - 1) * gap) / 2
    return { x: left + i * (width + gap), y: 570, width, height: n === 1 ? 740 : 660, labelX: n === 1 ? 72 : left + i * (width + gap), labelY: n === 1 ? 1380 : 1300, labelWidth: n === 1 ? 936 : width, font: n === 1 ? 40 : 32, labelLines: 3 }
  })
}

export function shelfPublicLink(handle, candidate, sharePath) {
  const fallback = `https://trove.schweg.xyz/@${encodeURIComponent(handle)}/shelf`
  try {
    const url = new URL(candidate || sharePath || fallback, 'https://trove.schweg.xyz')
    if (url.protocol === 'https:' && !url.username && !url.password && !['localhost', '127.0.0.1', '[::1]'].includes(url.hostname)) return url
  } catch { /* Use the public canonical default. */ }
  return new URL(fallback)
}

function seasonalFrame(ctx, theme, name, portrait) {
  const x = portrait ? 40 : 24, y = portrait ? 182 : 18, width = portrait ? 1000 : 1152, height = portrait ? 1556 : 594
  ctx.strokeStyle = theme.line; ctx.lineWidth = 2; ctx.strokeRect(x, y, width, height)
  ctx.fillStyle = theme.accent
  for (const left of [x, x + width - 52]) for (const top of [y, y + height - 3]) ctx.fillRect(left, top, 52, 3)
  if (!portrait) return
  if (name === 'halloween' || name === 'midnight_feature') {
    ctx.fillStyle = theme.accent; ctx.beginPath(); ctx.arc(980, 225, 19, 0, Math.PI * 2); ctx.fill()
    ctx.fillStyle = theme.bg; ctx.beginPath(); ctx.arc(988, 219, 18, 0, Math.PI * 2); ctx.fill()
  }
  if (name === 'christmas') {
    ctx.strokeStyle = theme.muted; ctx.lineWidth = 1.5
    for (const [left, drop] of [[912, 36], [948, 52], [985, 30]]) {
      ctx.beginPath(); ctx.moveTo(left, y); ctx.lineTo(left, y + drop); ctx.stroke()
      ctx.fillStyle = theme.accent; ctx.beginPath(); ctx.arc(left, y + drop + 9, 8, 0, Math.PI * 2); ctx.fill()
    }
    ctx.strokeStyle = theme.text; ctx.lineWidth = 2
    for (const [left, top, direction] of [[80, 1695, 1], [1000, 1695, -1]]) {
      ctx.beginPath(); ctx.moveTo(left, top); ctx.lineTo(left + direction * 90, top - 24)
      for (let i = 1; i < 6; i++) {
        const px = left + direction * i * 14, py = top - i * 4
        ctx.moveTo(px, py); ctx.lineTo(px - direction * 8, py - 17)
        ctx.moveTo(px, py); ctx.lineTo(px + direction * 2, py + 13)
      }
      ctx.stroke()
    }
  }
}

async function companionImage(name, theme, assets) {
  const selected = name === "auto" ? (theme === "halloween" ? "bat" : ["telly", "facet"].includes(theme) ? theme : "none") : name
  if (selected === "none" || !assets?.[selected]) return null
  const image = await cover({ cover: assets[selected] })
  return image ? { image, selected } : null
}

export async function renderShelfImage(canvas, { picks = [], shelves = [], overview, theme: themeName, format, handle, category, headline, layout = "exhibition", texture = "clean", companion = "auto", assets = {}, siteHost = "trove.schweg.xyz", sharePath, canonicalUrl }) {
  const portrait = format === "portrait", theme = SHELF_THEMES[themeName] || SHELF_THEMES.midnight
  const source = overview ? shelves.filter(shelf => shelf.picks.length) : [{ label: category, picks }]
  await document.fonts?.load('700 48px "Instrument Sans"')
  const [images, mascot, logo] = await Promise.all([
    Promise.all(source.map(shelf => Promise.all(shelf.picks.slice(0, 5).map(cover)))),
    companionImage(companion, themeName, assets), cover({ cover: assets.logo })
  ])
  const output = document.createElement("canvas")
  output.width = portrait ? 1080 : 1200; output.height = portrait ? 1920 : 630
  const ctx = output.getContext("2d"), w = output.width, h = output.height, edge = 72
  ctx.fillStyle = theme.bg; ctx.fillRect(0, 0, w, h)
  seasonalFrame(ctx, theme, themeName, portrait)
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
  const brandY = portrait ? 270 : 59
  if (logo) ctx.drawImage(logo, edge, brandY - (portrait ? 43 : 32), portrait ? 48 : 36, portrait ? 48 : 36)
  ctx.fillStyle = theme.text; ctx.font = `700 ${portrait ? 50 : 34}px "Instrument Sans", sans-serif`
  ctx.fillText('trove', edge + (logo ? (portrait ? 60 : 46) : 0), brandY)
  const edition = themeName === 'christmas' ? 'WINTER EDITION' : themeName === 'halloween' ? 'AFTER DARK' : horror ? 'MIDNIGHT FEATURE' : 'A PERSONAL COLLECTION'
  ctx.fillStyle = theme.accent; text(ctx, edition, portrait ? 520 : 825, brandY - 3, portrait ? 390 : 300, portrait ? 22 : 16, 1, '"Instrument Sans", sans-serif', 600)
  ctx.strokeStyle = theme.line; ctx.beginPath(); ctx.moveTo(edge, portrait ? 306 : 78); ctx.lineTo(w - edge, portrait ? 306 : 78); ctx.stroke()
  const heading = shelfImageHeading(headline)
  ctx.fillStyle = theme.text
  text(ctx, heading, edge, portrait ? 395 : 122, portrait ? (mascot ? 780 : 936) : 936, portrait ? 80 : 36, 2, horror ? 'Impact, "Arial Narrow", sans-serif' : 'Georgia, serif')
  ctx.fillStyle = theme.muted
  text(ctx, `@${handle} / ${overview ? 'The shelf' : category || 'Selections'}`, edge, portrait ? 520 : 185, portrait ? 850 : 1056, portrait ? 26 : 19, 1)
  if (mascot) {
    const image = mascot.image, height = portrait ? 112 : 76, width = height * image.width / image.height
    ctx.drawImage(image, w - edge - width, portrait ? 340 : 88, width, height)
  }
  const displayedPicks = overview && source.length === 1 ? source[0].picks : picks
  if (overview && source.length !== 1) {
    source.forEach((shelf, index) => {
      const x = portrait ? edge : edge + (index % 2) * 550
      const y = portrait ? 548 + index * 140 : 205 + Math.floor(index / 2) * 81
      ctx.fillStyle = theme.text; text(ctx, shelf.label, x, y + 28, portrait ? 156 : 96, portrait ? 26 : 17, 2)
      const count = Math.min(5, shelf.picks.length), width = portrait ? 78 : 57, height = portrait ? 117 : 68
      if (!count) { ctx.fillStyle = theme.muted; text(ctx, "A little room for the next discovery.", x + (portrait ? 180 : 110), y + 38, portrait ? 710 : 390, portrait ? 23 : 15, 1) }
      for (let i = 0; i < count; i++) artwork(ctx, images[index][i], x + (portrait ? 180 : 110) + i * (width + (portrait ? 68 : 22)), y, width, height, theme, i + 1, shelf.picks[i])
    })
  } else if (portrait) {
    portraitShelfLayout(displayedPicks.length, layout).forEach((box, i) => {
      ctx.save()
      if (layout === "mixtape") { const angle = [-0.045, 0.035, -0.03, 0.04, 0.025][i]; ctx.translate(box.x + box.width / 2, box.y + box.height / 2); ctx.rotate(angle); ctx.translate(-box.x - box.width / 2, -box.y - box.height / 2) }
      artwork(ctx, images[0][i], box.x, box.y, box.width, box.height, theme, i + 1, displayedPicks[i])
      if (layout === "mixtape" && images[0][i]) { ctx.globalAlpha = 0.65; ctx.fillStyle = themeName === 'christmas' ? theme.accent : theme.muted; ctx.fillRect(box.x + box.width / 2 - 34, box.y - 10, 68, 20); ctx.globalAlpha = 1 }
      ctx.restore()
      const types = { Album: 'MUSIC', TvShow: 'TV', Movie: 'FILM', Book: 'BOOK', Comic: 'COMIC', VideoGame: 'GAME' }
      ctx.fillStyle = theme.accent; text(ctx, `${String(i + 1).padStart(2, "0")} / ${types[displayedPicks[i].type] || 'PICK'}`, box.labelX, box.labelY, box.labelWidth, 18, 1, '"Instrument Sans", sans-serif', 600)
      ctx.fillStyle = theme.text; text(ctx, displayedPicks[i].title || "Untitled selection", box.labelX, box.labelY + 32, box.labelWidth, box.font, box.labelLines)
    })
    if (!displayedPicks.length) { ctx.fillStyle = theme.text; text(ctx, "A shelf taking shape.", edge, 840, 936, 64, 2); ctx.fillStyle = theme.muted; text(ctx, "Room for your next favorite.", edge, 970, 936, 32, 2) }
  } else {
    const n = Math.min(5, displayedPicks.length), width = 176, gap = 36, start = (w - (n * width + Math.max(0, n - 1) * gap)) / 2
    for (let i = 0; i < n; i++) {
      const x = start + i * (width + gap)
      artwork(ctx, images[0][i], x, 210, width, 230, theme, i + 1, displayedPicks[i])
      ctx.fillStyle = theme.text; text(ctx, `${i + 1}. ${displayedPicks[i].title || "Untitled selection"}`, x, 474, width, 19, 2)
    }
    if (!n) { ctx.fillStyle = theme.muted; text(ctx, "A shelf taking shape. Room for your next favorite.", edge, 320, 1056, 32, 2) }
  }
  const link = shelfPublicLink(handle, canonicalUrl, sharePath)
  ctx.strokeStyle = theme.line; ctx.beginPath(); ctx.moveTo(edge, portrait ? 1590 : h - 100); ctx.lineTo(w - edge, portrait ? 1590 : h - 100); ctx.stroke()
  ctx.fillStyle = theme.accent; text(ctx, 'OPEN THE FULL SHELF  →', edge, portrait ? 1624 : h - 72, w - edge * 2, portrait ? 20 : 15, 1, '"Instrument Sans", sans-serif', 600)
  ctx.fillStyle = theme.text; text(ctx, `${link.host}${link.pathname}${link.search}`, edge, portrait ? 1664 : h - 40, w - edge * 2, portrait ? 25 : 18, 1)
  canvas.width = w; canvas.height = h; canvas.getContext("2d").drawImage(output, 0, 0)
}
