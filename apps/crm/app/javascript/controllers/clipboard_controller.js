import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source"]

  async copy(event) {
    await navigator.clipboard.writeText(this.sourceTarget.innerText)
    event.currentTarget.textContent = "Copiado"
  }
}
