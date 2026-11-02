import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source"]

  disconnect() {
    this.status?.remove()
    this.status = null
  }

  async copy(event) {
    // currentTarget is cleared after event dispatch; capture it before awaiting.
    const button = event.currentTarget
    const label = button.textContent
    try {
      await navigator.clipboard.writeText(this.sourceTarget.innerText)
      if (!this.element.isConnected) return
      button.textContent = "Copiado"
      this.announce("Texto copiado al portapapeles.")
    } catch {
      if (!this.element.isConnected) return
      button.textContent = label
      this.announce("No se pudo copiar. Seleccioná el texto para copiarlo manualmente.")
    }
  }

  announce(message) {
    if (!this.status) {
      this.status = document.createElement("p")
      this.status.className = "arm-section-note"
      this.status.setAttribute("role", "status")
      this.status.setAttribute("aria-live", "polite")
      this.status.setAttribute("aria-atomic", "true")
      this.element.appendChild(this.status)
    }
    this.status.textContent = message
  }
}
