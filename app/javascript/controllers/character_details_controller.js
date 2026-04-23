import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["avatarPreview", "nameInput", "tab", "panel", "factsCountBadge"]
  static values = {currentSection: String}

  connect() {
    this.activateSection(this.currentSectionValue || this.defaultSection)

    if (this.hasNameInputTarget && this.nameInputTarget.value.trim() === "") {
      this.nameInputTarget.focus()
    }
  }

  disconnect() {
    if (!this.avatarPreviewObjectUrl) return
    URL.revokeObjectURL(this.avatarPreviewObjectUrl)
    this.avatarPreviewObjectUrl = null
  }

  showSection(event) {
    event.preventDefault()
    this.activateSection(event.currentTarget.dataset.section)
  }

  handleAvatarChange(event) {
    const file = event.target.files[0]
    if (!file) return

    if (this.avatarPreviewObjectUrl) {
      URL.revokeObjectURL(this.avatarPreviewObjectUrl)
    }

    const previewUrl = URL.createObjectURL(file)
    this.avatarPreviewObjectUrl = previewUrl

    const currentAvatar = this.avatarPreviewTarget.querySelector("#character-avatar-preview") || this.avatarPreviewTarget.firstElementChild
    if (!currentAvatar) return

    if (currentAvatar.tagName === "IMG") {
      currentAvatar.src = previewUrl
      return
    }

    const previewImage = document.createElement("img")
    previewImage.id = currentAvatar.id || "character-avatar-preview"
    previewImage.className = currentAvatar.className
    previewImage.src = previewUrl
    previewImage.alt = this.hasNameInputTarget ? this.nameInputTarget.value.trim() : ""

    this.avatarPreviewTarget.replaceChildren(previewImage)
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
