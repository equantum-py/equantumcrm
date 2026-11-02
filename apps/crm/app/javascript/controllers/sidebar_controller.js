import { Controller } from "@hotwired/stimulus"

// Mobile drawer: keyboard access, focus return and Turbo cache cleanup.
export default class extends Controller {
  static targets = ["panel", "backdrop", "trigger"]

  connect() {
    this.media = window.matchMedia("(min-width: 1024px)")
    this.onResize = () => {
      if (!this.media.matches) return
      const wasOpen = this.opened
      this.close({ restoreFocus: false })
      if (wasOpen) this.panelTarget.querySelector('[aria-current="page"]')?.focus()
    }
    this.media.addEventListener("change", this.onResize)
    this.onTab = event => this.trapFocus(event)
    this.panelTarget.addEventListener("keydown", this.onTab)
  }

  disconnect() {
    this.media.removeEventListener("change", this.onResize)
    this.panelTarget.removeEventListener("keydown", this.onTab)
    this.restoreBackground()
    if (this.opened) document.body.style.overflow = this.previousOverflow || ""
  }

  open() {
    if (this.media.matches || this.opened) return
    this.opened = true
    this.previousFocus = document.activeElement
    this.previousOverflow = document.body.style.overflow
    this.panelTarget.classList.remove("hidden")
    this.panelTarget.classList.add("flex")
    this.panelTarget.setAttribute("role", "dialog")
    this.panelTarget.setAttribute("aria-modal", "true")
    this.backdropTarget.classList.remove("hidden")
    this.triggerTarget.setAttribute("aria-expanded", "true")
    this.background = [...this.element.children]
      .filter(element => element !== this.panelTarget && element !== this.backdropTarget)
      .map(element => [element, element.inert])
    this.background.forEach(([element]) => { element.inert = true })
    document.body.style.overflow = "hidden"
    this.focusableElements()[0]?.focus()
  }

  close({ restoreFocus = true } = {}) {
    const wasOpen = this.opened
    this.opened = false
    this.panelTarget.classList.add("hidden")
    this.panelTarget.classList.remove("flex")
    this.panelTarget.removeAttribute("role")
    this.panelTarget.removeAttribute("aria-modal")
    this.backdropTarget.classList.add("hidden")
    this.triggerTarget.setAttribute("aria-expanded", "false")
    this.restoreBackground()
    if (wasOpen) {
      document.body.style.overflow = this.previousOverflow || ""
      if (restoreFocus && this.previousFocus?.isConnected) this.previousFocus.focus()
    }
  }

  restoreBackground() {
    this.background?.forEach(([element, inert]) => { element.inert = inert })
    this.background = null
  }

  navigate(event) {
    if (event.target.closest("a[href]")) this.close()
  }

  focusableElements() {
    return [...this.panelTarget.querySelectorAll("a[href], button, input, select, textarea, [tabindex]")]
      .filter(element => element.tabIndex >= 0 && !element.disabled && element.getClientRects().length)
  }

  trapFocus(event) {
    if (!this.opened || event.key !== "Tab") return
    const elements = this.focusableElements()
    const first = elements[0], last = elements.at(-1)
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last?.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first?.focus()
    }
  }
}
