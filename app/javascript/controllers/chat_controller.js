import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["timeline", "placeholder", "activeRuns"]

  connect() {
    this.scrollToLastMessage()
    document.addEventListener("turbo:after-stream-render", this.scrollAfterRender)
    document.addEventListener("turbo:render", this.scrollOnRefresh)
  }

  disconnect() {
    document.removeEventListener("turbo:after-stream-render", this.scrollAfterRender)
    document.removeEventListener("turbo:render", this.scrollOnRefresh)
  }

  scrollToLastMessage(behavior = "instant") {
    const container = this.element
    this.followingEnd = true
    container.scrollTo({
      top: container.scrollHeight - container.clientHeight,
      behavior
    })
  }

  trackScroll() {
    const { scrollHeight, scrollTop, clientHeight } = this.element
    this.followingEnd = scrollHeight - scrollTop - clientHeight <= 48
  }

  scrollAfterRender = (event) => {
    const { action, target } = event.detail || {}
    if (action === "reload_agent_run") return

    if (action === "before" && this.hasPlaceholderTarget && target === this.placeholderTarget.id) {
      const message = this.placeholderTarget.previousElementSibling
      if (message?.dataset.chatOrder) this.placeEntry(message, this.timelineTarget, this.placeholderTarget)
    }

    this.scrollToLastMessage("smooth")
  }

  placeAgentRun(event) {
    const frame = event.target
    if (!frame.matches("turbo-frame[data-agent-run-frame]")) return

    const card = frame.firstElementChild
    if (!card) {
      frame.remove()
      return
    }

    frame.dataset.chatOrder = card.dataset.chatOrder
    if (card.hasAttribute("data-agent-run-active")) {
      this.placeEntry(frame, this.activeRunsTarget)
    } else {
      this.placeEntry(frame, this.timelineTarget, this.placeholderTarget)
    }

    if (this.followingEnd) this.scrollToLastMessage("smooth")
  }

  placeEntry(entry, container, end = null) {
    const next = Array.from(container.children).find((item) => {
      return item !== entry && item.dataset.chatOrder > entry.dataset.chatOrder
    }) || end
    if (entry.parentElement !== container || entry.nextElementSibling !== next) container.insertBefore(entry, next)
  }

  preserveRunDetails(event) {
    if (event.target === event.currentTarget && event.detail.attributeName === "open") {
      event.preventDefault()
    }
  }

  scrollOnRefresh = () => {
    this.scrollToLastMessage()
  }
}
