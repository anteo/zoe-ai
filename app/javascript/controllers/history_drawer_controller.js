import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "panel", "title", "backButton", "listView", "detailView", "detailFrame", "listFrame"]
  static values = {
    listTitle: String,
    listUrl: String
  }

  connect() {
    this.currentIndex = null
    this.detailOpen = false
  }

  open() {
    this.loadList()
    this.toggleTarget.checked = true
  }

  close() {
    this.toggleTarget.checked = false
    this.showList()
    this.clearSelection()
  }

  handleToggleChange() {
    if (this.toggleTarget.checked) this.loadList()
  }

  openChat(event) {
    this.selectLink(event.currentTarget)
    this.showDetail()
    this.detailFrameTarget.src = event.currentTarget.href
  }

  showList() {
    this.detailOpen = false
    this.backButtonTarget.classList.add("hidden")
    this.detailViewTarget.classList.add("hidden")
    this.detailViewTarget.classList.remove("block")
    this.listViewTarget.classList.remove("hidden")
    this.panelTarget.classList.remove("max-w-6xl")
    this.panelTarget.classList.add("max-w-[26rem]")
    this.detailFrameTarget.innerHTML = ""
  }

  openByIndex(index) {
    const link = this.chatLinks[index]
    if (!link) return

    this.selectLink(link)
    this.showDetail()
    this.detailFrameTarget.src = link.href
  }

  get chatLinks() {
    return Array.from(this.element.querySelectorAll("[data-history-drawer-chat-link='true']"))
  }

  loadList() {
    if (!this.hasListFrameTarget || this.listFrameTarget.src || !this.hasListUrlValue) return

    this.listFrameTarget.src = this.listUrlValue
  }

  handleKeydown(event) {
    if (!this.toggleTarget.checked) return
    if (this.isTypingTarget(event.target)) return

    switch (event.key) {
      case "Escape":
        if (this.detailOpen) {
          this.showList()
        } else {
          this.close()
        }
        break
      case "ArrowDown":
        this.moveSelection(1)
        event.preventDefault()
        break
      case "ArrowUp":
        this.moveSelection(-1)
        event.preventDefault()
        break
    }
  }

  moveSelection(offset) {
    if (!this.chatLinks.length) return

    const nextIndex = Number.isInteger(this.currentIndex)
      ? Math.min(Math.max(this.currentIndex + offset, 0), this.chatLinks.length - 1)
      : offset > 0 ? 0 : this.chatLinks.length - 1

    this.openByIndex(nextIndex)
  }

  clearSelection() {
    this.currentIndex = null
    this.chatLinks.forEach((chatLink) => {
      chatLink.classList.remove("menu-active")
    })
  }

  selectLink(link) {
    if (!link) return

    this.currentIndex = Number(link.dataset.historyDrawerIndex)
    this.chatLinks.forEach((chatLink) => {
      chatLink.classList.toggle("menu-active", chatLink === link)
    })

    link.scrollIntoView({ behavior: "smooth", block: "nearest" })
  }

  showDetail() {
    this.detailOpen = true
    this.backButtonTarget.classList.toggle("hidden", this.isDesktop())
    this.detailViewTarget.classList.remove("hidden")
    this.detailViewTarget.classList.add("block")
    this.listViewTarget.classList.toggle("hidden", !this.isDesktop())
    this.panelTarget.classList.remove("max-w-[26rem]")
    this.panelTarget.classList.add("max-w-6xl")
  }

  isDesktop() {
    return window.matchMedia("(min-width: 1024px)").matches
  }

  isTypingTarget(target) {
    return target instanceof HTMLElement && (
      target.isContentEditable ||
      ["INPUT", "TEXTAREA", "SELECT"].includes(target.tagName)
    )
  }
}
