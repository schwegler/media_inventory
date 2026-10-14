export const SHELF_THEMES = {
  midnight: { bg: '#101117', text: '#f6f3eb', muted: '#aaaab1', accent: '#dfff8e', surface: '#202127', line: '#ffffff26' },
  gallery: { bg: '#f5f2eb', text: '#22221f', muted: '#66665e', accent: '#415338', surface: '#e5e1d7', line: '#22221f30' },
  electric: { bg: '#181235', text: '#fff4f6', muted: '#bcb0d7', accent: '#ff9ccf', surface: '#30234f', line: '#fff4f630' }
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

function text(ctx, value, x, y, width, size, lines = 2) {
  ctx.font = `${size}px sans-serif`
  const words = value.split(/\s+/)
  for (let line = 0; line < lines && words.length; line++) {
    let result = words.shift()
    while (words.length && ctx.measureText(`${result} ${words[0]}`).width <= width) result += ` ${words.shift()}`
    if (line === lines - 1 && words.length) result += '…'
    while (ctx.measureText(result).width > width && result.length > 1) result = `${result.slice(0, -2)}…`
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

export async function renderShelfImage(canvas, { picks, shelves, overview, theme: themeName, format, handle, category }) {
  const portrait = format === 'portrait', theme = SHELF_THEMES[themeName] || SHELF_THEMES.midnight
  const source = overview ? shelves : [{ label: category, picks }]
  const images = await Promise.all(source.map(shelf => Promise.all(shelf.picks.map(cover))))
  // Render to a detached canvas so a superseded preview cannot corrupt an export.
  const output = document.createElement('canvas')
  output.width = portrait ? 1080 : 1200; output.height = portrait ? 1920 : 630
  const ctx = output.getContext('2d'), w = output.width, h = output.height
  ctx.fillStyle = theme.bg; ctx.fillRect(0, 0, w, h)
  ctx.fillStyle = theme.text; ctx.font = `${portrait ? 40 : 26}px Georgia`; ctx.fillText('Trove', 48, portrait ? 70 : 44)
  ctx.fillStyle = theme.muted; ctx.font = `${portrait ? 24 : 15}px sans-serif`; ctx.fillText(`@${handle}’s Shelf`, 48, portrait ? 116 : 74)
  ctx.fillStyle = theme.text; ctx.font = `${portrait ? 86 : 52}px Georgia`
  textHeading(overview ? 'The things I keep.' : `My top five · ${category}`, portrait ? 208 : 137)
  function textHeading(value, y) {
    let size = portrait ? 86 : 52
    while (ctx.measureText(value).width > w - 96 && size > 34) { size -= 2; ctx.font = `${size}px Georgia` }
    ctx.fillText(value, 48, y, overview && !portrait ? 500 : w - 96)
  }
  if (overview) {
    source.forEach((shelf, index) => {
      const featured = index === 0
      const x = portrait ? 48 : (featured ? 600 : 48 + ((index - 1) % 2) * 570)
      const y = portrait ? (featured ? 285 : 560 + (index - 1) * 208) : (featured ? 50 : 235 + Math.floor((index - 1) / 2) * 105)
      const width = portrait ? 984 : 534
      const labelWidth = portrait ? 150 : 100
      const coverHeight = portrait ? (featured ? 230 : 175) : (featured ? 130 : 90)
      const coverWidth = coverHeight * 2 / 3
      const gap = (width - labelWidth - coverWidth * 5) / 4
      ctx.fillStyle = theme.text; ctx.font = `${portrait ? 28 : 20}px Georgia`; ctx.fillText(shelf.label, x, y + 24, labelWidth - 8)
      ctx.fillStyle = theme.accent; ctx.font = `${portrait ? 18 : 11}px sans-serif`; ctx.fillText(String(index + 1).padStart(2, '0'), x, y + 54)
      for (let i = 0; i < 5; i++) artwork(ctx, images[index][i], x + labelWidth + i * (coverWidth + gap), y, coverWidth, coverHeight, theme, i + 1, shelf.picks[i])
      ctx.fillStyle = theme.surface; ctx.fillRect(x + labelWidth - 4, y + coverHeight, width - labelWidth + 8, portrait ? 8 : 5)
    })
  } else {
    for (let i = 0; i < 5; i++) {
      let x, y, width, height
      if (portrait) {
        width = i === 0 ? 300 : 240; height = width * 1.5
        x = i === 0 ? 390 : 180 + ((i - 1) % 2) * 480
        y = i === 0 ? 290 : 880 + Math.floor((i - 1) / 2) * 440
      } else { x = 48 + i * 224; y = 190; width = 208; height = 280 }
      artwork(ctx, images[0][i], x, y, width, height, theme, i + 1, picks[i])
      ctx.fillStyle = theme.accent; ctx.font = `${portrait ? 28 : 20}px Georgia`; ctx.fillText(String(i + 1).padStart(2, '0'), x, y + height + 28)
      ctx.fillStyle = theme.text; text(ctx, picks[i]?.title || 'Not picked yet', x, y + height + (portrait ? 62 : 55), width, portrait ? 24 : 17, 2)
    }
  }
  ctx.strokeStyle = theme.line; ctx.beginPath(); ctx.moveTo(48, h - 65); ctx.lineTo(w - 48, h - 65); ctx.stroke()
  ctx.fillStyle = theme.muted; ctx.font = `${portrait ? 24 : 16}px sans-serif`
  text(ctx, `${window.location.host}/@${handle}/shelf`, 48, h - 29, w - 96, portrait ? 24 : 16, 1)
  canvas.width = w; canvas.height = h; canvas.getContext('2d').drawImage(output, 0, 0)
}
