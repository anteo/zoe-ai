import {Controller} from "@hotwired/stimulus"
import Cropper from "cropperjs"

export default class extends Controller {
  static targets = ["cropperHost", "cropImage", "modalBox"]
  static values = {sourceUrl: String, fileName: String}

  connect() {
    this.accepted = false
    if (!this.hasSourceUrlValue) return

    this.cropImageTarget.onload = () => {
      this.cropImageTarget.onload = null
      this.initializeCropper()
    }
    this.cropImageTarget.src = this.sourceUrlValue
  }

  disconnect() {
    this.destroyCropper()
    if (this.hasCropImageTarget) this.cropImageTarget.src = ""
  }

  async apply(event) {
    event.preventDefault()
    if (!this.cropper) return

    const canvas = this.cropper.getCroppedCanvas({
      width: 512,
      height: 512,
      imageSmoothingEnabled: true,
      imageSmoothingQuality: "high"
    })
    if (!canvas) return

    const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/png"))
    if (!blob) return

    const file = new File([blob], this.buildFileName(), {type: "image/png", lastModified: Date.now()})
    this.accepted = true
    this.dispatch("apply", {detail: {file}})
    this.element.close()
  }

  cancel(event) {
    event.preventDefault()
    this.accepted = false
    this.element.close()
  }

  handleCancel(event) {
    event.preventDefault()
    event.stopPropagation()
    this.accepted = false
    this.element.close()
  }

  handleEscape(event) {
    event.preventDefault()
    event.stopPropagation()
    this.accepted = false
    this.element.close()
  }

  async handleClose() {
    await this.waitForCloseAnimation()
    this.destroyCropper()
    this.dispatch("closed", {detail: {accepted: this.accepted}})
  }

  initializeCropper() {
    this.destroyCropper()
    this.cropper = new Cropper(this.cropImageTarget, {
      viewMode: 1,
      dragMode: "move",
      aspectRatio: 1,
      autoCropArea: 0.75,
      background: false,
      responsive: true,
      restore: false,
      movable: true,
      zoomable: true,
      rotatable: false,
      scalable: false,
      cropBoxMovable: true,
      cropBoxResizable: true
    })
  }

  destroyCropper() {
    if (!this.cropper) return
    if (typeof this.cropper.destroy === "function") {
      this.cropper.destroy()
    } else if (this.hasCropperHostTarget) {
      this.cropperHostTarget.innerHTML = ""
    }
    this.cropper = null
  }

  async waitForCloseAnimation() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    await new Promise((resolve) => {
      let done = false
      const finish = () => {
        if (done) return
        done = true
        this.modalBoxTarget.removeEventListener("animationend", finish)
        resolve()
      }

      this.modalBoxTarget.addEventListener("animationend", finish, {once: true})
      window.setTimeout(finish, 180)
    })
  }

  buildFileName() {
    const originalName = this.fileNameValue || "avatar.png"
    const baseName = originalName.replace(/\.[^.]+$/, "")
    return `${baseName}-cropped.png`
  }
}
