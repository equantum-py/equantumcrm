import { Controller } from "@hotwired/stimulus"

// Presentation controls apply only to the explicitly labelled loaded result set.
export default class extends Controller {
  static targets = ["row", "body", "verification", "sort", "count", "empty"]

  connect() {
    this.titleCollator = new Intl.Collator("es", { sensitivity: "base", numeric: true })
    this.filter()
    this.sort()
  }

  filter() {
    const verification = this.verificationTarget.value
    let count = 0
    this.rowTargets.forEach(row => {
      row.hidden = Boolean(verification && row.dataset.verification !== verification)
      if (!row.hidden) count++
    })
    this.countTarget.textContent = count
    this.emptyTarget.hidden = count > 0 || !this.rowTargets.length
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
