import { Controller } from "@hotwired/stimulus"
import { createPhotoSwipeLightbox } from "../lib/photoswipe"

export default class extends Controller {
  static values = {
    refreshDelay: { type: Number, default: 100 }
  }

  connect() {
    this.observer = new MutationObserver(() => this.scheduleRefresh())
    this.observer.observe(this.element, {
      subtree: true,
      childList: true,
      attributes: true,
      attributeFilter: ["class", "data-pswp-width", "data-pswp-height", "href"]
    })
    this.refresh()
  }

  disconnect() {
    this.observer?.disconnect()
    this.observer = null
    this.cancelScheduledRefresh()
    this.destroyLightbox()
  }

  refresh() {
    this.cancelScheduledRefresh()
    const signature = this.gallerySignature()
    const hasLinks = signature.length > 0

    if (!hasLinks) {
      this.destroyLightbox()
      this.gallerySignatureValue = ""
      return
    }

    if (this.lightbox && this.gallerySignatureValue === signature) {
      return
    }

    this.destroyLightbox()
    this.lightbox = createPhotoSwipeLightbox(this.element)
    this.gallerySignatureValue = signature
  }

  scheduleRefresh() {
    if (this.refreshTimeout) {
      return
    }

    this.refreshTimeout = window.setTimeout(() => {
      this.refreshTimeout = null
      this.refresh()
    }, this.refreshDelayValue)
  }

  cancelScheduledRefresh() {
    if (!this.refreshTimeout) {
      return
    }

    clearTimeout(this.refreshTimeout)
    this.refreshTimeout = null
  }

  destroyLightbox() {
    if (!this.lightbox) {
      return
    }

    this.lightbox.destroy()
    this.lightbox = null
  }

  gallerySignature() {
    return Array.from(this.element.querySelectorAll(".lightbox-link"))
      .map((link) => [
        link.getAttribute("href") || "",
        link.dataset.pswpWidth || "",
        link.dataset.pswpHeight || ""
      ].join("|"))
      .join("\n")
  }
}
