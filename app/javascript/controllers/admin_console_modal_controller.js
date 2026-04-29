import {Controller} from "@hotwired/stimulus"
import {createAdminConsoleSubscription} from "../channels/admin_console_channel"

export default class extends Controller {
  static targets = ["output", "placeholder"]

  connect() {
    this.autoScroll = true
    this.boundOnScroll = this.onScroll.bind(this)
    this.outputTarget.addEventListener("scroll", this.boundOnScroll)
    this.subscription = createAdminConsoleSubscription({
      onMessage: (payload) => this.append(payload)
    })
  }

  disconnect() {
    this.outputTarget.removeEventListener("scroll", this.boundOnScroll)
    this.subscription?.unsubscribe()
  }

  open() {
    if (!this.element.open) this.element.showModal()
  }

  close(event) {
    event?.preventDefault()
    if (this.element.open) this.element.close()
  }

  backdropClick(event) {
    if (event.target !== this.element) return
    this.close()
  }

  handleEscape(event) {
    if (!this.element.open) return
    event.preventDefault()
    event.stopImmediatePropagation()
    this.close()
  }

  append(payload) {
    if (!payload?.message) return

    this.placeholderTargets.forEach((node) => node.remove())
    const row = document.createElement("div")
    row.className = `console-log-row ${this.severityClass(payload.severity)}`
    row.textContent = this.formatLine(payload)
    this.outputTarget.appendChild(row)

    if (this.autoScroll) {
      this.outputTarget.scrollTop = this.outputTarget.scrollHeight
    }
  }

  formatLine(payload) {
    const timestamp = payload.timestamp ? `[${payload.timestamp}] ` : ""
    return `${timestamp}${payload.message}`
  }

  severityClass(severity) {
    switch (severity) {
      case "debug":
        return "console-log-debug"
      case "warn":
        return "console-log-warn"
      case "error":
      case "fatal":
        return "console-log-error"
      default:
        return "console-log-info"
    }
  }

  onScroll() {
    const threshold = 16
    const delta = this.outputTarget.scrollHeight - this.outputTarget.scrollTop - this.outputTarget.clientHeight
    this.autoScroll = delta <= threshold
  }
}
