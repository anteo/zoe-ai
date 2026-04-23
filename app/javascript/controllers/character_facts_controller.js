import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["rows", "row", "textFilter", "persistentFilter", "topicFilter", "sortFilter"]

  connect() {
    this.sortRows(this.currentSortDirection())
    this.applyFilters()
    this.updateCountBadge()

    this.form = this.element.closest("form")
    this.boundBeforeSubmit = this.prepareChangedFactsForSubmit.bind(this)
    this.form?.addEventListener("submit", this.boundBeforeSubmit)
  }

  disconnect() {
    this.form?.removeEventListener("submit", this.boundBeforeSubmit)
    if (this.filterTimer) clearTimeout(this.filterTimer)
  }

  applyFilters() {
    const textQuery = (this.hasTextFilterTarget ? this.textFilterTarget.value : "").trim().toLowerCase()
    const persistentValue = this.hasPersistentFilterTarget ? this.persistentFilterTarget.value : "all"
    const topicValue = this.hasTopicFilterTarget ? this.topicFilterTarget.value : ""

    this.rowTargets.forEach((row) => {
      const rowText = (row.dataset.searchText || "").toLowerCase()
      const rowPersistent = row.dataset.persistent
      const rowTopic = row.dataset.topic || ""

      const textMatch = textQuery === "" || rowText.includes(textQuery)
      const persistentMatch = persistentValue === "all" || rowPersistent === persistentValue
      const topicMatch = topicValue === "" || rowTopic === topicValue

      row.classList.toggle("hidden", !(textMatch && persistentMatch && topicMatch))
    })
  }

  queueApplyFilters() {
    if (this.filterTimer) clearTimeout(this.filterTimer)
    this.filterTimer = setTimeout(() => this.applyFilters(), 120)
  }

  handleSortChange() {
    this.sortRows(this.currentSortDirection())
    this.applyFilters()
  }

  sortRows(direction) {
    const sortedRows = [...this.rowTargets].sort((a, b) => {
      const aTs = Number.parseInt(a.dataset.mentionedAt || "0", 10)
      const bTs = Number.parseInt(b.dataset.mentionedAt || "0", 10)
      return direction === "asc" ? aTs - bTs : bTs - aTs
    })

    sortedRows.forEach((row) => row.parentElement.appendChild(row))
  }

  syncSearchText(event) {
    const row = event.currentTarget.closest("tr")
    if (!row) return

    const content = event.currentTarget.value || ""
    const author = row.dataset.author || ""
    const topic = row.dataset.topic || ""
    row.dataset.searchText = `${content} ${author} ${topic}`.toLowerCase()

    if (this.hasActiveTextFilter()) {
      this.queueApplyFilters()
    }
  }

  toggleDelete(event) {
    event.preventDefault()

    const row = event.currentTarget.closest("tr")
    if (!row) return

    const destroyInput = row.querySelector("input[name*='[_destroy]']")
    if (!destroyInput) return

    const shouldDelete = destroyInput.value !== "1"
    destroyInput.value = shouldDelete ? "1" : "0"

    row.classList.toggle("opacity-40", shouldDelete)
    row.classList.toggle("line-through", shouldDelete)
    this.updateCountBadge()
  }

  updateCountBadge() {
    this.dispatch("count-changed", {detail: {count: this.activeFactsCount()}})
  }

  activeFactsCount() {
    return this.rowTargets.filter((row) => {
      const destroyInput = row.querySelector("input[name*='[_destroy]']")
      return !destroyInput || destroyInput.value !== "1"
    }).length
  }

  prepareChangedFactsForSubmit() {
    this.rowTargets.forEach((row) => {
      const idInput = row.querySelector("[data-role='id']")
      const destroyInput = row.querySelector("[data-role='destroy']")
      const contentInput = row.querySelector("[data-role='content']")
      if (!idInput || !destroyInput || !contentInput) return

      const deleted = destroyInput.value === "1"
      const changed = contentInput.value !== (contentInput.dataset.originalContent || "")

      if (deleted) {
        idInput.disabled = false
        destroyInput.disabled = false
        contentInput.disabled = true
        return
      }

      if (changed) {
        idInput.disabled = false
        destroyInput.disabled = true
        contentInput.disabled = false
        return
      }

      idInput.disabled = true
      destroyInput.disabled = true
      contentInput.disabled = true
    })
  }

  currentSortDirection() {
    return this.hasSortFilterTarget ? this.sortFilterTarget.value : "desc"
  }

  hasActiveTextFilter() {
    return this.hasTextFilterTarget && this.textFilterTarget.value.trim().length > 0
  }
}
