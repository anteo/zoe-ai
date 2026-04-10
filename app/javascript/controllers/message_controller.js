import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["view", "edit", "textarea"]

  startEdit() {
    this.viewTarget.classList.add("hidden")
    this.editTarget.classList.remove("hidden")
    this.textareaTarget.focus()
    // Move cursor to end
    const ta = this.textareaTarget
    ta.selectionStart = ta.selectionEnd = ta.value.length
  }

  cancelEdit() {
    this.editTarget.classList.add("hidden")
    this.viewTarget.classList.remove("hidden")
  }
}
