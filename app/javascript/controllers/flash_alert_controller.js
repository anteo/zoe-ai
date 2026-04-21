import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    timeoutMs: Number,
    closeDurationMs: Number
  }

  connect() {
    if (!this.hasTimeoutMsValue || this.timeoutMsValue <= 0) return

    this.timeoutId = window.setTimeout(() => {
      this.dismiss()
    }, this.timeoutMsValue)
  }

  disconnect() {
    if (this.timeoutId) {
      window.clearTimeout(this.timeoutId)
      this.timeoutId = null
    }
  }

  dismiss(event) {
    event?.preventDefault()
    if (this.element.classList.contains("is-closing")) return

    this.element.classList.add("is-closing")
    this.disconnect()

    const removeAlert = () => this.element.remove()
    this.element.addEventListener("animationend", removeAlert, { once: true })

    // Ensure animation is complete before removing
    window.setTimeout(removeAlert, 300)
  }
}
