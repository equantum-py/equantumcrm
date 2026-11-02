import { Controller } from "@hotwired/stimulus"

// Presentation controls apply only to the explicitly labelled loaded result set.
export default class extends Controller {
  static targets = ["row", "body", "verification", "sort", "count", "empty"]

  connect() {
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
    this.countTarget.setAttribute("aria-live", "polite")
    this.emptyTarget.hidden = count > 0 || !this.rowTargets.length
  }

  sort() {
    if (!this.hasBodyTarget) return
    const key = this.sortTarget.value
    const rows = [...this.rowTargets].sort((a, b) => {
      if (key === "title") return a.dataset.title.localeCompare(b.dataset.title, "es")
      const field = key === "recent" ? "detected" : "score"
      return Number(b.dataset[field]) - Number(a.dataset[field]) || Number(b.dataset.detected) - Number(a.dataset.detected)
    })
    rows.forEach(row => this.bodyTarget.appendChild(row))
  }
}
