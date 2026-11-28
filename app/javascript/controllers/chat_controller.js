import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
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
    if (event.detail?.action === "reload_agent_runs") return

    this.scrollToLastMessage("smooth")
  }

  scrollAfterAgentRunsRender(event) {
    if (this.followingEnd && event.target.matches("turbo-frame[data-agent-runs-url]")) {
      this.scrollToLastMessage("smooth")
    }
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
