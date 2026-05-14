import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    delay: { type: Number, default: 250 }
  }

  connect() {
    this.timeoutId = null
  }

  disconnect() {
    this.clearTimeout()
  }

  submit(event) {
    if (event?.target?.type === "hidden") return

    this.clearTimeout()
    this.timeoutId = window.setTimeout(() => {
      this.element.requestSubmit()
    }, this.delayValue)
  }

  clearTimeout() {
    if (!this.timeoutId) return

    window.clearTimeout(this.timeoutId)
    this.timeoutId = null
  }
}
