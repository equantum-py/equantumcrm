import { Controller } from "@hotwired/stimulus"

// Folds a <details> on phones and opens it from the lg breakpoint up, so
// the mobile page stays short without hiding anything on desktop.
export default class extends Controller {
  connect() {
    if (window.matchMedia("(min-width: 1024px)").matches) this.element.open = true
  }
}
