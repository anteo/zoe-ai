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
    container.scrollTo({
      top: container.scrollHeight - container.clientHeight,
      behavior
    })
  }

  scrollAfterRender = () => {
    this.scrollToLastMessage("smooth")
  }

  scrollOnRefresh = () => {
    this.scrollToLastMessage()
  }
}
