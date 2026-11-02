import { Controller } from "@hotwired/stimulus"

// Native GET filter submission without inline script, compatible with CSP/Turbo.
export default class extends Controller {
  submit() {
    this.element.form?.requestSubmit()
  }
}
