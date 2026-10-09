import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "output", "count"]
  static values = { default: String, limit: Number }

  connect() { this.update() }

  update() {
    const samples = {
      title: "The Grand Budapest Hotel", type: "added", rating: "4",
      review: "A beautifully told story.", link: "https://trove.schweg.xyz/movies/123-example-movie"
    }
    const template = this.inputTarget.value.trim() || this.defaultValue
    const text = template.replace(/\[(title|type|rating|review|link)\]/g, (_, key) => samples[key])
    const length = typeof Intl.Segmenter === "function"
      ? [...new Intl.Segmenter(undefined, { granularity: "grapheme" }).segment(text)].length
      : Array.from(text).length
    this.outputTarget.textContent = text
    this.countTarget.textContent = `${length}/${this.limitValue} characters in this sample${length > this.limitValue ? " — shorten your template before sharing." : ". Actual length depends on the item."}`
  }
}
