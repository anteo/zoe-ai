import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.handleFieldChange = this.handleFieldChange.bind(this)

    this.element.addEventListener("input", this.handleFieldChange, true)
    this.element.addEventListener("change", this.handleFieldChange, true)
  }

  disconnect() {
    this.element.removeEventListener("input", this.handleFieldChange, true)
    this.element.removeEventListener("change", this.handleFieldChange, true)
  }

  handleFieldChange(event) {
    const field = event.target.closest("input, textarea, select")
    if (!field) return

    this.removeInlineHint(field)

    field.removeAttribute("aria-invalid")

    for (const className of [...field.classList]) {
      if (className.endsWith("-error")) {
        field.classList.remove(className)
      }
    }
  }

  removeInlineHint(field) {
    const wrapper = field.closest(".has-error")
    if (wrapper) {
      wrapper.classList.remove("has-error")
      wrapper.querySelectorAll(":scope > .text-error").forEach((node) => node.remove())
      return
    }

    const fieldNode = field.closest(".field_with_errors") || field

    const nextNode = fieldNode.nextElementSibling
    if (nextNode?.classList?.contains("text-error")) {
      nextNode.remove()
      return
    }

    const parentHint = fieldNode.parentElement?.querySelector(":scope > .text-error")
    parentHint?.remove()
  }
}
