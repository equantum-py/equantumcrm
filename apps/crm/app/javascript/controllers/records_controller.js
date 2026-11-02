import { Controller } from "@hotwired/stimulus"

// Presentation controls apply only to the explicitly labelled loaded result set.
export default class extends Controller {
  static targets = ["row", "body", "sort"]

  connect() {
    this.titleCollator = new Intl.Collator("es", { sensitivity: "base", numeric: true })
    this.sort()
  }

  sort() {
    if (!this.hasBodyTarget) return
    const key = this.sortTarget.value
    const rows = [...this.rowTargets].sort((a, b) => {
      if (key === "title") return this.titleCollator.compare(a.dataset.title, b.dataset.title)
      const field = key === "recent" ? "detected" : "score"
      return Number(b.dataset[field]) - Number(a.dataset[field]) || Number(b.dataset.detected) - Number(a.dataset.detected)
    })
    const fragment = document.createDocumentFragment()
    rows.forEach(row => fragment.appendChild(row))
    this.bodyTarget.appendChild(fragment)
  }
}
