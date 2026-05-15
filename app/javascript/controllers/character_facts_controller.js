import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["draftStore", "row"]
  static values = { totalCount: Number }

  connect() {
    this.updateCountBadge()
  }

  disconnect() {
    this.cancelPendingRestore()
  }

  rowTargetConnected(row) {
    this.restoreRow(row)
    this.updateCountBadge()
  }

  handleContentInput(event) {
    const row = event.currentTarget.closest("tr")
    if (!row) return

    this.syncDraftForRow(row)
  }

  restoreDrafts() {
    this.cancelPendingRestore()
    this.restoreFrame = window.requestAnimationFrame(() => {
      this.rowTargets.forEach((row) => this.restoreRow(row))
      this.updateCountBadge()
      this.restoreFrame = null
    })
  }

  storeDrafts() {
    this.rowTargets.forEach((row) => this.syncDraftForRow(row))
  }

  toggleDelete(event) {
    event.preventDefault()

    const row = event.currentTarget.closest("tr")
    if (!row) return

    row.dataset.deleted = this.deleted(row) ? "false" : "true"
    this.applyRowState(row)
    this.syncDraftForRow(row)
  }

  activeFactsCount() {
    return Math.max(this.totalCountValue - this.deletedDraftCount(), 0)
  }

  applyRowState(row) {
    row.classList.toggle("opacity-40", this.deleted(row))
    row.classList.toggle("line-through", this.deleted(row))
  }

  contentInput(row) {
    return row.querySelector("[data-role='content']")
  }

  contentDisplay(row) {
    return row.querySelector("[data-role='content-display']")
  }

  deleted(row) {
    return row.dataset.deleted === "true"
  }

  deletedDraftCount() {
    return this.draftEntries().filter((entry) => this.draftDeleted(entry)).length
  }

  draftContent(entry) {
    return entry.querySelector("[data-role='content']")?.value || ""
  }

  draftDeleted(entry) {
    return entry.querySelector("[data-role='destroy']")?.value === "1"
  }

  draftEntries() {
    return this.hasDraftStoreTarget ? Array.from(this.draftStoreTarget.querySelectorAll("[data-fact-id]")) : []
  }

  draftEntry(factId) {
    return this.hasDraftStoreTarget ? this.draftStoreTarget.querySelector(`[data-fact-id="${factId}"]`) : null
  }

  ensureDraftEntry(factId) {
    let entry = this.draftEntry(factId)
    if (entry) return entry

    entry = document.createElement("div")
    entry.dataset.factId = factId

    entry.appendChild(this.hiddenInput(`character[facts_attributes][${factId}][id]`, factId, "id"))
    entry.appendChild(this.hiddenInput(`character[facts_attributes][${factId}][content]`, "", "content"))
    entry.appendChild(this.hiddenInput(`character[facts_attributes][${factId}][_destroy]`, "0", "destroy"))

    this.draftStoreTarget.appendChild(entry)
    return entry
  }

  hiddenInput(name, value, role) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    input.value = value
    input.dataset.role = role
    return input
  }

  originalContent(row) {
    return row.dataset.originalContent || ""
  }

  removeDraft(factId) {
    this.draftEntry(factId)?.remove()
  }

  restoreRow(row) {
    const draft = this.draftEntry(row.dataset.factId)
    const contentInput = this.contentInput(row)
    const contentDisplay = this.contentDisplay(row)

    if (!draft) {
      row.dataset.deleted = "false"
      this.applyRowState(row)
      return
    }

    if (contentInput) {
      contentInput.value = this.draftContent(draft)
    }

    if (contentDisplay) {
      contentDisplay.textContent = this.draftContent(draft)
    }

    row.dataset.deleted = this.draftDeleted(draft) ? "true" : "false"
    this.applyRowState(row)
  }

  syncDraftForRow(row) {
    const factId = row.dataset.factId
    const contentInput = this.contentInput(row)
    const content = contentInput ? contentInput.value : this.originalContent(row)
    const deleted = this.deleted(row)

    if (!deleted && content === this.originalContent(row)) {
      this.removeDraft(factId)
      this.updateCountBadge()
      return
    }

    const entry = this.ensureDraftEntry(factId)
    entry.querySelector("[data-role='content']").value = content
    entry.querySelector("[data-role='destroy']").value = deleted ? "1" : "0"

    this.updateCountBadge()
  }

  updateCountBadge() {
    this.dispatch("count-changed", { detail: { count: this.activeFactsCount() } })
  }

  cancelPendingRestore() {
    if (!this.restoreFrame) return

    window.cancelAnimationFrame(this.restoreFrame)
    this.restoreFrame = null
  }
}
