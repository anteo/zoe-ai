import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { maxHeight: Number }

  connect() {
    this.boundResize = this.resize.bind(this)
    this.element.addEventListener("input", this.boundResize)
    this.resize()
  }

  disconnect() {
    this.element.removeEventListener("input", this.boundResize)
  }

  resize() {
    if (!(this.element instanceof HTMLTextAreaElement)) return

    this.element.style.height = "auto"

    const fullHeight = this.element.scrollHeight
    const maxHeight = this.hasMaxHeightValue ? this.maxHeightValue : null
    const nextHeight = maxHeight ? Math.min(fullHeight, maxHeight) : fullHeight

    this.element.style.height = `${nextHeight}px`
    this.element.style.overflowY = maxHeight && fullHeight > maxHeight ? "auto" : "hidden"
  }
}
