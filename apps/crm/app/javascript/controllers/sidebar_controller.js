import { Controller } from "@hotwired/stimulus"

// Toggles the navigation drawer on small screens.
export default class extends Controller {
  static targets = ["panel", "backdrop"]

  open() {
    this.panelTarget.classList.remove("hidden")
    this.panelTarget.classList.add("flex")
    this.backdropTarget.classList.remove("hidden")
  }

  close() {
    this.panelTarget.classList.add("hidden")
    this.panelTarget.classList.remove("flex")
    this.backdropTarget.classList.add("hidden")
  }
}
