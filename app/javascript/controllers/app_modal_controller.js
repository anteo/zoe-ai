import {Controller} from "@hotwired/stimulus"
import {waitForCloseAnimation} from "../lib/wait_for_close_animation"

export default class extends Controller {
  static targets = ["frame"]

  static values = {
    referrerFrameId: String
  }

  connect() {
    this.boundBeforeFetchRequestHandler = (event) => this.appendReferrerFrameHeader(event)
    document.addEventListener("turbo:before-fetch-request", this.boundBeforeFetchRequestHandler)
    if (this.element.open) return
    this.element.showModal()
  }

  disconnect() {
    if (!this.boundBeforeFetchRequestHandler) return
    document.removeEventListener("turbo:before-fetch-request", this.boundBeforeFetchRequestHandler)
  }

  close(event) {
    if (event?.type === "cancel" && event.target !== this.element) {
      event.preventDefault()
      event.stopPropagation()
      return
    }

    event?.preventDefault()
    this.closeModal()
  }

  backdropClick(event) {
    if (event.target !== this.element) return
    this.closeModal()
  }

  async closeModal() {
    if (this.closing) return
    this.closing = true

    this.element.classList.remove("modal-open")
    try {
      this.element.close()
    } catch (_) {
    }

    await this.removeWrapper()
    this.closing = false
  }

  async removeWrapper() {
    await waitForCloseAnimation({
      nodes: [this.element, this.element.querySelector(".modal-box")]
    })

    this.element.remove()
  }

  appendReferrerFrameHeader(event) {
    if (!this.hasReferrerFrameIdValue || this.referrerFrameIdValue.length === 0) return

    const requestTarget = event.target
    if (!this.shouldAttachHeader(requestTarget)) return

    const headers = event.detail?.fetchOptions?.headers
    if (!headers) return

    if (headers instanceof Headers) {
      headers.set("X-Turbo-Referrer-Frame-Id", this.referrerFrameIdValue)
      return
    }

    headers["X-Turbo-Referrer-Frame-Id"] = this.referrerFrameIdValue
  }

  shouldAttachHeader(requestTarget) {
    if (!(requestTarget instanceof Element)) return false
    if (this.element.contains(requestTarget)) return true

    return this.matchesGeneratedTurboMethodForm(requestTarget)
  }

  matchesGeneratedTurboMethodForm(requestTarget) {
    if (!this.hasFrameTarget || !this.frameTarget.id) return false
    if (!(requestTarget instanceof HTMLFormElement)) return false

    return requestTarget.getAttribute("data-turbo-frame") === this.frameTarget.id
  }
}
