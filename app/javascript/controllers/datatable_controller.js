import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["filtersForm", "resultsFrame"]

  connect() {
    this.syncSortField()
  }

  beforeRefresh() {
    this.dispatch("before-refresh")
  }

  afterRefresh() {
    this.syncSortField()
    this.dispatch("after-refresh")
  }

  syncSortField() {
    if (!this.hasFiltersFormTarget || !this.hasResultsFrameTarget) return

    const fieldName = "q[s]"
    const currentSort = this.resultsFrameTarget.dataset.currentSortValue || ""
    let sortInput = this.filtersFormTarget.querySelector(`input[name="${fieldName}"]`)

    if (!sortInput && currentSort === "") return

    if (!sortInput) {
      sortInput = document.createElement("input")
      sortInput.type = "hidden"
      sortInput.name = fieldName
      this.filtersFormTarget.appendChild(sortInput)
    }

    sortInput.value = currentSort
  }
}
