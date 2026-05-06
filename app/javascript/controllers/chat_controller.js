import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.scrollToLastMessage()
    document.addEventListener("turbo:after-stream-render", this.scrollAfterRender)
  }

  disconnect() {
    document.removeEventListener("turbo:after-stream-render", this.scrollAfterRender)
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
}
