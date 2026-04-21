import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "panel", "title", "timeSpan", "backButton", "listView", "detailView", "detailFrame", "listFrame", "navButtons", "previousButton", "nextButton"]
  static values = {
    listTitle: String,
    listUrl: String
  }

  connect() {
    this.currentIndex = null
    this.updateNavigationState()
  }

  open() {
    this.loadList()
    this.overlayTarget.classList.remove("hidden")
    requestAnimationFrame(() => {
      this.overlayTarget.classList.remove("opacity-0")
      this.panelTarget.classList.remove("translate-x-full")
    })
  }

  close() {
    this.overlayTarget.classList.add("opacity-0")
    this.panelTarget.classList.add("translate-x-full")

    setTimeout(() => {
      this.overlayTarget.classList.add("hidden")
    }, 200)

    this.showList()
  }

  openChat(event) {
    const title = event.currentTarget.dataset.historyDrawerTitle
    const timeSpan = event.currentTarget.dataset.historyDrawerTimeSpan
    this.currentIndex = Number(event.currentTarget.dataset.historyDrawerIndex)
    this.titleTarget.textContent = title || this.listTitleValue
    this.updateTimeSpan(timeSpan)
    this.backButtonTarget.classList.remove("hidden")
    this.navButtonsTarget.classList.remove("hidden")
    this.navButtonsTarget.classList.add("flex")
    this.listViewTarget.classList.add("hidden")
    this.detailViewTarget.classList.remove("hidden")
    this.startFrameTransition()
    this.updateNavigationState()
  }

  openPrevious() {
    this.openByIndex(this.currentIndex + 1)
  }

  openNext() {
    this.openByIndex(this.currentIndex - 1)
  }

  showList() {
    this.currentIndex = null
    this.titleTarget.textContent = this.listTitleValue
    this.updateTimeSpan(null)
    this.backButtonTarget.classList.add("hidden")
    this.navButtonsTarget.classList.add("hidden")
    this.navButtonsTarget.classList.remove("flex")
    this.detailViewTarget.classList.add("hidden")
    this.listViewTarget.classList.remove("hidden")
    this.detailFrameTarget.innerHTML = ""
    this.updateNavigationState()
  }

  openByIndex(index) {
    const link = this.chatLinks[index]
    if (!link) return

    this.currentIndex = index
    const title = link.dataset.historyDrawerTitle
    const timeSpan = link.dataset.historyDrawerTimeSpan
    this.titleTarget.textContent = title || this.listTitleValue
    this.updateTimeSpan(timeSpan)
    this.startFrameTransition()
    this.detailFrameTarget.src = link.href
    this.updateNavigationState()
  }

  startFrameTransition() {
    this.detailFrameTarget.classList.add("is-loading")
    this.detailFrameTarget.classList.remove("is-ready")
  }

  finishFrameTransition() {
    this.detailFrameTarget.classList.remove("is-loading")
    this.detailFrameTarget.classList.add("is-ready")
  }

  updateTimeSpan(timeSpan) {
    if (!this.hasTimeSpanTarget) return

    if (timeSpan) {
      this.timeSpanTarget.textContent = timeSpan
      this.timeSpanTarget.classList.remove("hidden")
      return
    }

    this.timeSpanTarget.textContent = ""
    this.timeSpanTarget.classList.add("hidden")
  }

  updateNavigationState() {
    if (!this.hasPreviousButtonTarget || !this.hasNextButtonTarget) return

    const hasCurrent = Number.isInteger(this.currentIndex)
    const hasOlder = hasCurrent && this.currentIndex < this.chatLinks.length - 1
    const hasNewer = hasCurrent && this.currentIndex > 0

    this.previousButtonTarget.disabled = !hasOlder
    this.nextButtonTarget.disabled = !hasNewer
  }

  get chatLinks() {
    return Array.from(this.element.querySelectorAll("[data-history-drawer-chat-link='true']"))
  }

  loadList() {
    if (!this.hasListFrameTarget || this.listFrameTarget.src || !this.hasListUrlValue) return

    this.listFrameTarget.src = this.listUrlValue
  }

  handleKeydown(event) {
    if (event.key === "Escape" && !this.overlayTarget.classList.contains("hidden")) {
      this.close()
    }
  }
}
