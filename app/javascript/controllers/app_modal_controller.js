import {Controller} from "@hotwired/stimulus"
import {clearAppModalSnapshots, popAppModalSnapshot} from "../lib/app_modal"

export default class extends Controller {
  static CLOSE_FALLBACK_MS = 350

  connect() {
    this.show()
  }

  show() {
    const frame = this.element.closest("turbo-frame#modal")
    const replacing = frame?.dataset.appModalReplacing === "true"
    if (replacing) {
      this.disableTransitionsForReplacement()
      delete frame.dataset.appModalReplacing
    }

    if (this.element.open) {
      if (replacing) {
        requestAnimationFrame(() => this.restoreTransitionsAfterReplacement())
      }
      return
    }

    const x = window.scrollX
    const y = window.scrollY

    this.element.showModal()
    window.scrollTo(x, y)

    if (replacing) {
      requestAnimationFrame(() => this.restoreTransitionsAfterReplacement())
    }
  }

  async close(event) {
    event?.preventDefault()
    await this.closeModal()
  }

  async requestClose(event) {
    event.preventDefault()
    await this.closeModal()
  }

  async cancel(event) {
    event.preventDefault()
    await this.closeModal()
  }

  async backdropClick(event) {
    if (event.target !== this.element) return
    await this.closeModal()
  }

  async submitEnd(event) {
    if (!event.detail.success) return

    const response = event.detail.fetchResponse?.response
    if (!response) return
    if (response.redirected) {
      const frame = this.element.closest("turbo-frame#modal")
      if (frame) frame.dataset.appModalReplacing = "true"
      clearAppModalSnapshots()
      return
    }
    if (response.status !== 204) return

    await this.closeModal()
  }

  async closeModal() {
    const frame = this.element.closest("turbo-frame#modal")
    if (frame && popAppModalSnapshot(frame)) return
    if (this.closing) return
    this.closing = true

    // Let DaisyUI/native dialog transitions handle leave animation.
    this.element.classList.remove("modal-open")
    try {
      this.element.close()
    } catch (_) {
    }

    await this.waitForCloseAnimation()

    this.element.remove()

    if (frame) {
      clearAppModalSnapshots()
      frame.removeAttribute("src")
      frame.innerHTML = ""
      frame.dispatchEvent(new Event("app-modal:closed"))
    }

    this.closing = false
  }

  async waitForCloseAnimation() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      return
    }

    const nodes = [this.element, this.element.querySelector(".modal-box")].filter(Boolean)
    const animations = nodes.flatMap((node) => node.getAnimations().filter((a) => a.playState !== "finished"))

    if (animations.length > 0) {
      await Promise.all(animations.map((animation) => animation.finished.catch(() => null)))
    } else {
      await new Promise((resolve) => window.setTimeout(resolve, this.constructor.CLOSE_FALLBACK_MS))
    }
  }

  disableTransitionsForReplacement() {
    if (this.element.dataset.appModalTransitionBackup === undefined) {
      this.element.dataset.appModalTransitionBackup = this.element.style.transition || ""
    }
    this.element.style.transition = "none"

    const box = this.element.querySelector(".modal-box")
    if (!box) return

    if (box.dataset.appModalTransitionBackup === undefined) {
      box.dataset.appModalTransitionBackup = box.style.transition || ""
    }
    box.style.transition = "none"
  }

  restoreTransitionsAfterReplacement() {
    this.element.style.transition = this.element.dataset.appModalTransitionBackup || ""
    delete this.element.dataset.appModalTransitionBackup

    const box = this.element.querySelector(".modal-box")
    if (!box) return

    box.style.transition = box.dataset.appModalTransitionBackup || ""
    delete box.dataset.appModalTransitionBackup
  }
}
