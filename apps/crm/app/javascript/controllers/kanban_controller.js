import { Controller } from "@hotwired/stimulus"

// Drag and drop between pipeline columns. Persists through PATCH /opportunities/:id/move.
// Moving to a "lost" column asks for the reason, which the server requires.
export default class extends Controller {
  static targets = ["column"]

  dragstart(event) {
    event.dataTransfer.setData("text/plain", event.currentTarget.dataset.id)
    event.dataTransfer.effectAllowed = "move"
  }

  dragover(event) {
    event.preventDefault()
    event.currentTarget.classList.add("ring-2", "ring-indigo-300")
  }

  dragleave(event) {
    event.currentTarget.classList.remove("ring-2", "ring-indigo-300")
  }

  async drop(event) {
    event.preventDefault()
    const column = event.currentTarget
    column.classList.remove("ring-2", "ring-indigo-300")
    const id = event.dataTransfer.getData("text/plain")
    const card = this.element.querySelector(`[data-id="${id}"]`)
    if (!card || card.parentElement === column.querySelector("[data-cards]")) return

    const body = new FormData()
    body.append("pipeline_stage_id", column.dataset.stageId)
    if (column.dataset.stageKind === "lost") {
      const reason = window.prompt("Motivo de pérdida:")
      if (!reason) return
      body.append("lost_reason", reason)
    }

    const response = await fetch(`/opportunities/${id}/move`, {
      method: "PATCH",
      body,
      headers: { "Accept": "application/json", "X-CSRF-Token": document.querySelector("meta[name=csrf-token]").content }
    })
    if (response.ok) {
      Turbo.visit(window.location.href, { action: "replace" })
    } else {
      window.alert("No se pudo mover la oportunidad. Verificá tus permisos.")
    }
  }
}
