import {Controller} from "@hotwired/stimulus"
import dayjs from "dayjs"
import {createAdminConsoleSubscription} from "../channels/admin_console_channel"

export default class extends Controller {
  static targets = ["levelSelect", "output"]

  connect() {
    this.autoScroll = true
    this.hasSnapshotRows = false
    this.hasUnreadDivider = false
    this.maxLines = Infinity
    this.storageKey = "adminConsole.level"
    this.boundOnScroll = this.onScroll.bind(this)
    this.outputTarget.addEventListener("scroll", this.boundOnScroll)
    this.levelSelectTarget.value = this.loadSelectedLevel()
    this.subscribe(this.levelSelectTarget.value)
  }

  disconnect() {
    this.outputTarget.removeEventListener("scroll", this.boundOnScroll)
    this.subscription?.unsubscribe()
  }

  changeLevel() {
    this.persistSelectedLevel(this.levelSelectTarget.value)
    this.subscribe(this.levelSelectTarget.value)
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

  subscribe(level) {
    this.subscription?.unsubscribe()
    this.subscription = createAdminConsoleSubscription(level, {
      onAppend: (payload) => this.append(payload),
      onSnapshot: (payload) => this.replace(payload)
    })
  }

  replace(payload) {
    const logs = payload?.logs || []
    this.hasSnapshotRows = false
    this.hasUnreadDivider = false
    this.maxLines = Number.parseInt(payload?.limit || this.outputTarget.dataset.limit || "0", 10) || Infinity
    this.outputTarget.innerHTML = ""

    if (payload?.level && this.levelSelectTarget.value !== payload.level) {
      this.levelSelectTarget.value = payload.level
    }

    if (logs.length === 0) {
      this.renderEmptyState()
      return
    }

    logs.forEach((log) => this.append(log, true))
    this.hasSnapshotRows = true
    this.outputTarget.scrollTop = this.outputTarget.scrollHeight
  }

  append(payload, snapshot = false) {
    if (!payload?.message) return

    this.clearEmptyState()
    if (!snapshot) this.insertUnreadDivider()
    this.outputTarget.appendChild(this.buildRow(payload))
    this.trimRows()

    if (!snapshot && this.autoScroll) {
      this.outputTarget.scrollTop = this.outputTarget.scrollHeight
    }
  }

  formatLine(payload) {
    const timestamp = payload.logged_at ? `[${this.formatTimestamp(payload.logged_at)}] ` : ""
    return `${timestamp}${payload.message}`
  }

  formatTimestamp(value) {
    return dayjs(value).format("YYYY-MM-DD HH:mm:ss")
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

  buildRow(payload) {
    const row = document.createElement("div")
    row.className = `console-log-row ${this.severityClass(payload.severity)}`
    row.textContent = this.formatLine(payload)
    return row
  }

  clearEmptyState() {
    this.outputTarget.querySelector("[data-empty-state]")?.remove()
  }

  insertUnreadDivider() {
    if (!this.hasSnapshotRows || this.hasUnreadDivider) return

    const divider = document.createElement("div")
    divider.className = "flex items-center gap-3 py-2 text-[10px] uppercase tracking-[0.24em] text-neutral-content/50"
    divider.dataset.unreadDivider = "true"
    divider.innerHTML = `
      <span class="h-px flex-1 bg-neutral-content/15"></span>
      <span>${this.outputTarget.dataset.newMessagesLabel}</span>
      <span class="h-px flex-1 bg-neutral-content/15"></span>
    `

    this.outputTarget.appendChild(divider)
    this.hasUnreadDivider = true
  }

  renderEmptyState() {
    this.outputTarget.innerHTML = ""

    const placeholder = document.createElement("p")
    placeholder.className = "text-neutral-content/60"
    placeholder.dataset.emptyState = "true"
    placeholder.textContent = this.outputTarget.dataset.emptyText
    this.outputTarget.appendChild(placeholder)
  }

  trimRows() {
    while (this.outputTarget.children.length > this.maxLines) {
      this.outputTarget.firstElementChild?.remove()
    }
  }

  loadSelectedLevel() {
    try {
      return window.localStorage.getItem(this.storageKey) || this.levelSelectTarget.value || "info"
    } catch (_error) {
      return this.levelSelectTarget.value || "info"
    }
  }

  persistSelectedLevel(level) {
    try {
      window.localStorage.setItem(this.storageKey, level)
    } catch (_error) {
      // Ignore storage failures and keep the in-memory selection.
    }
  }

  onScroll() {
    const threshold = 16
    const delta = this.outputTarget.scrollHeight - this.outputTarget.scrollTop - this.outputTarget.clientHeight
    this.autoScroll = delta <= threshold
  }
}
