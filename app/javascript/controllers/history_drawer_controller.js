import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "panel", "backButton", "listView", "detailView", "detailFrame", "listFrame", "resultsFrame", "searchForm", "searchInput", "agentBack", "agentFrame"]
  static values = {
    listUrl: String
  }

  connect() {
    this.currentIndex = null
    this.detailOpen = false
    this.selectedChatId = null
    this.searchTimeout = null
  }

  open() {
    this.opener = document.activeElement
    delete this.panelTarget.dataset.agents
    this.loadList()
    this.toggleTarget.checked = true
  }

  close() {
    this.toggleTarget.checked = false
    delete this.panelTarget.dataset.agents
    this.historyLink = null
    this.showList()
    this.clearSelection()
    this.opener?.focus({ preventScroll: true })
    this.opener = null
  }

  handleToggleChange() {
    if (this.toggleTarget.checked) this.loadList()
    else this.close()
  }

  openAgentDetail(event) {
    if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    event.preventDefault()
    const link = event.currentTarget
    if (this.toggleTarget.checked) this.historyLink = link
    else this.opener = link

    const frame = this.agentFrameTarget
    frame.dataset.agentConversationId = link.dataset.agentConversationId
    this.panelTarget.dataset.agents = "detail"
    this.toggleTarget.checked = true
    this.agentBackTarget.focus({ preventScroll: true })
    if (frame.src === link.href) {
      this.scrollAgentToBottom()
      frame.reload()
    } else {
      frame.src = link.href
    }
  }

  scrollAgentToBottom() {
    if (this.panelTarget.dataset.agents !== "detail") return

    const frame = this.agentFrameTarget
    frame.scrollTop = frame.scrollHeight
  }

  backFromAgent() {
    if (this.historyLink) {
      delete this.panelTarget.dataset.agents
      this.historyLink.focus({ preventScroll: true })
      this.historyLink = null
    } else {
      this.close()
    }
  }

  openChat(event) {
    this.selectLink(event.currentTarget)
    this.showDetail()
    this.detailFrameTarget.classList.add("is-loading")
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
    this.detailFrameTarget.classList.add("is-loading")
    this.detailFrameTarget.src = link.href
  }

  get chatLinks() {
    return Array.from(this.element.querySelectorAll("[data-history-drawer-chat-link='true']"))
  }

  loadList() {
    if (!this.hasListFrameTarget || this.listFrameTarget.src || !this.hasListUrlValue) return

    this.listFrameTarget.src = this.listUrlValue
  }

  queueSearch() {
    if (!this.hasSearchFormTarget) return

    clearTimeout(this.searchTimeout)
    this.searchTimeout = setTimeout(() => {
      this.searchFormTarget.requestSubmit()
    }, 200)
  }

  submitSearch() {
    clearTimeout(this.searchTimeout)
  }

  focusFirstSearchResult(event) {
    const selectedLink = this.selectedChatId
      ? this.chatLinks.find((link) => link.dataset.historyDrawerChatId === this.selectedChatId)
      : null
    const targetLink = selectedLink || this.chatLinks[0]
    if (!targetLink) return

    event.preventDefault()
    if (selectedLink) {
      this.selectLink(selectedLink)
      this.showDetail()
      selectedLink.focus({ preventScroll: true })
      return
    }

    this.openByIndex(0)
    targetLink.focus({ preventScroll: true })
  }

  selectSearchText(event) {
    event.target.select()
  }

  syncListState() {
    if (!this.selectedChatId) return

    const selectedLink = this.chatLinks.find((link) => link.dataset.historyDrawerChatId === this.selectedChatId)
    if (selectedLink) {
      this.selectLink(selectedLink)
      return
    }

    this.showList()
    this.clearSelection()
  }

  finishFrameTransition() {
    this.detailFrameTarget.classList.remove("is-loading")
  }

  handleKeydown(event) {
    if (!this.toggleTarget.checked) return
    if (this.panelTarget.dataset.agents) {
      if (event.key === "Escape") this.close()
      return
    }
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
    this.selectedChatId = null
    this.chatLinks.forEach((chatLink) => {
      chatLink.classList.remove("menu-active")
    })
  }

  selectLink(link) {
    if (!link) return

    this.currentIndex = Number(link.dataset.historyDrawerIndex)
    this.selectedChatId = link.dataset.historyDrawerChatId
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
