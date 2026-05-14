import {Controller} from "@hotwired/stimulus"
import {waitForCloseAnimation} from "../lib/wait_for_close_animation"

export default class extends Controller {
  static targets = ["body", "footer", "frame"]

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

  submitFromFooter(event) {
    const submitter = event.target.closest("button, input")
    if (!submitter || !this.footerTarget.contains(submitter)) return
    if (!this.isSubmitControl(submitter)) return
    if (submitter.form) return

    const form = this.findBodyForm(submitter)
    if (!form) return

    event.preventDefault()
    const proxySubmitter = this.buildProxySubmitter(submitter, form)

    try {
      form.requestSubmit(proxySubmitter)
    } finally {
      proxySubmitter.remove()
    }
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

  isSubmitControl(element) {
    if (element.tagName === "BUTTON") {
      return (element.getAttribute("type") || "submit").toLowerCase() === "submit"
    }

    if (element.tagName === "INPUT") {
      return element.type === "submit"
    }

    return false
  }

  findBodyForm(submitter) {
    const selector = submitter.getAttribute("data-modal-form-selector")
    if (selector) return this.bodyTarget.querySelector(selector)

    return this.bodyTarget.querySelector("form")
  }

  buildProxySubmitter(submitter, form) {
    const proxy = document.createElement("button")
    proxy.type = "submit"
    proxy.hidden = true

    if (submitter.name) proxy.name = submitter.name
    if ("value" in submitter) proxy.value = submitter.value

    for (const attribute of ["formaction", "formmethod", "formenctype", "formtarget"]) {
      const value = submitter.getAttribute(attribute)
      if (value !== null) proxy.setAttribute(attribute, value)
    }

    if (submitter.hasAttribute("formnovalidate")) {
      proxy.setAttribute("formnovalidate", "")
    }

    form.append(proxy)
    return proxy
  }
}
