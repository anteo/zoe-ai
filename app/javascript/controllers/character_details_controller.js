import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["nameInput", "tab", "panel", "factsCountBadge"]
  static values = {currentSection: String}

  connect() {
    this.activateSection(this.currentSectionValue || this.defaultSection)

    if (this.hasNameInputTarget && this.nameInputTarget.value.trim() === "") {
      this.nameInputTarget.focus()
    }
  }

  showSection(event) {
    event.preventDefault()
    this.activateSection(event.currentTarget.dataset.section)
  }

  updateFactsCountBadge(event) {
    if (!this.hasFactsCountBadgeTarget) return

    const count = Number.parseInt(`${event.detail?.count ?? ""}`, 10)
    if (Number.isNaN(count)) return

    this.factsCountBadgeTarget.textContent = count
  }

  activateSection(section) {
    if (!this.hasTabTarget || !this.hasPanelTarget) return

    const activeSection = section || this.defaultSection
    this.currentSectionValue = activeSection

    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.section === activeSection
      tab.classList.toggle("tab-active", active)
      tab.setAttribute("aria-selected", active ? "true" : "false")
    })

    this.panelTargets.forEach((panel) => {
      const active = panel.dataset.section === activeSection
      panel.classList.toggle("hidden", !active)
    })
  }

  get defaultSection() {
    return this.tabTargets[0]?.dataset.section
  }
}
