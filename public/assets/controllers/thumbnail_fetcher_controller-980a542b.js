import { Controller } from "@hotwired/stimulus"

// Debounce helper
function debounce(func, wait) {
  let timeout
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout)
      func(...args)
    }
    clearTimeout(timeout)
    timeout = setTimeout(later, wait)
  }
}

// Connects to data-controller="thumbnail-fetcher"
export default class extends Controller {
  static targets = ["titleInput", "secondaryInput", "previewImg", "placeholder", "statusText", "optionsGrid", "thumbnailUrl"]
  static values = { mediaType: String }

  connect() {
    this.debouncedFetch = debounce(() => this.fetchThumbnails(), 600)

    // Pre-populate preview if thumbnail URL already has a value
    if (this.thumbnailUrlTarget.value) {
      this.previewImgTarget.src = this.thumbnailUrlTarget.value
      this.previewImgTarget.style.display = "block"
      this.placeholderTarget.style.display = "none"
    }
  }

  search() {
    this.debouncedFetch()
  }

  async fetchThumbnails() {
    const title = this.titleInputTarget.value.trim()
    if (!title) {
      this.optionsGridTarget.innerHTML = ""
      this.statusTextTarget.textContent = "Type title to fetch covers..."
      return
    }

    this.statusTextTarget.textContent = "Searching web for covers..."
    this.optionsGridTarget.innerHTML = ""

    let query = title
    if (this.hasSecondaryInputTarget && this.secondaryInputTarget.value.trim()) {
      query += " " + this.secondaryInputTarget.value.trim()
    }

    try {
      let results = []
      const mediaType = this.mediaTypeValue

      if (mediaType === "movie") {
        const url = `https://itunes.apple.com/search?term=${encodeURIComponent(query)}&media=movie&limit=5`
        const response = await fetch(url)
        const data = await response.json()
        results = (data.results || []).map(r => r.artworkUrl100 ? r.artworkUrl100.replace("100x100bb", "400x400bb") : null).filter(Boolean)
      } else if (mediaType === "album") {
        const url = `https://itunes.apple.com/search?term=${encodeURIComponent(query)}&media=music&entity=album&limit=5`
        const response = await fetch(url)
        const data = await response.json()
        results = (data.results || []).map(r => r.artworkUrl100 ? r.artworkUrl100.replace("100x100bb", "500x500bb") : null).filter(Boolean)
      } else if (mediaType === "tv_show") {
        const url = `https://itunes.apple.com/search?term=${encodeURIComponent(query)}&media=tvShow&limit=5`
        const response = await fetch(url)
        const data = await response.json()
        results = (data.results || []).map(r => r.artworkUrl100 ? r.artworkUrl100.replace("100x100bb", "400x400bb") : null).filter(Boolean)
      } else if (mediaType === "comic") {
        const url = `https://www.googleapis.com/books/v1/volumes?q=${encodeURIComponent(query)}&maxResults=5`
        const response = await fetch(url)
        const data = await response.json()
        results = (data.items || []).map(item => {
          const imageLinks = item.volumeInfo?.imageLinks
          return imageLinks?.thumbnail || imageLinks?.smallThumbnail
        }).filter(Boolean).map(url => url.replace("http://", "https://"))
      } else if (mediaType === "wrestling_event") {
        const url = `https://itunes.apple.com/search?term=${encodeURIComponent(query)}&limit=5`
        const response = await fetch(url)
        const data = await response.json()
        results = (data.results || []).map(r => r.artworkUrl100 ? r.artworkUrl100.replace("100x100bb", "400x400bb") : null).filter(Boolean)
      }

      if (results.length === 0) {
        this.statusTextTarget.textContent = "No covers found. Standard category icon will be used."
        return
      }

      this.statusTextTarget.textContent = "Select a cover:"

      results.forEach((imgUrl, index) => {
        const imgBtn = document.createElement("div")
        imgBtn.className = "thumbnail-option-card"
        imgBtn.innerHTML = `<img src="${imgUrl}" alt="Option ${index + 1}">`

        imgBtn.addEventListener("click", () => {
          this.optionsGridTarget.querySelectorAll(".thumbnail-option-card").forEach(card => card.classList.remove("selected"))
          imgBtn.classList.add("selected")

          this.thumbnailUrlTarget.value = imgUrl
          this.previewImgTarget.src = imgUrl
          this.previewImgTarget.style.display = "block"
          this.placeholderTarget.style.display = "none"
        })

        this.optionsGridTarget.appendChild(imgBtn)
      })

      // Auto-select first cover
      const firstCard = this.optionsGridTarget.querySelector(".thumbnail-option-card")
      if (firstCard) firstCard.click()

    } catch (err) {
      console.error("Error fetching thumbnails:", err)
      this.statusTextTarget.textContent = "Error loading covers."
    }
  }
}
