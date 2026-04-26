import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["preview", "input", "dialogTemplate", "removeFlag", "removeButton", "attachmentId", "fallbackTemplate"]
  static values = {canRemove: Boolean}

  connect() {
    this.setRemoveButtonVisible(this.canRemoveValue)
    this.setAttachmentControlsEnabled(this.hasRemoveFlagTarget && this.removeFlagTarget.value === "1")
  }

  disconnect() {
    this.cleanupSourceObjectUrl()
    this.cleanupPreviewObjectUrl()
    this.removeActiveDialog()
  }

  rememberFiles() {
    this.previousFiles = this.inputTarget.files ? Array.from(this.inputTarget.files) : []
    this.previousRemoveFlag = this.hasRemoveFlagTarget ? this.removeFlagTarget.value : "0"
    this.previousAttachmentId = this.hasAttachmentIdTarget ? this.attachmentIdTarget.value : ""
    this.previousCanRemove = this.hasRemoveButtonTarget ? this.removeButtonTarget.classList.contains("hidden") === false : false
    this.previousAttachmentControlsEnabled = this.hasRemoveFlagTarget ? !this.removeFlagTarget.disabled : false
  }

  openCropper(event) {
    const file = event.target.files[0]
    if (!file || !file.type.startsWith("image/")) return

    this.setRemoveFlag(false)
    this.setAttachmentControlsEnabled(false)
    this.cleanupSourceObjectUrl()
    this.pendingFile = file
    this.sourceObjectUrl = URL.createObjectURL(file)

    this.mountDialog()
    this.openDialog()
  }

  handleDialogApply(event) {
    const file = event.detail?.file
    if (!file) return
    this.setRemoveFlag(false)
    this.setAttachmentIdFlag(false)
    this.setAttachmentControlsEnabled(false)
    this.setRemoveButtonVisible(true)
    this.replaceInputFiles([file])
    this.updatePreview(file)
    this.keepSelection = true
  }

  handleDialogClosed(event) {
    const accepted = Boolean(event.detail?.accepted)
    if (!accepted && !this.keepSelection) {
      this.restorePreviousState()
    }
    this.keepSelection = false
    this.pendingFile = null
    this.cleanupSourceObjectUrl()
    this.removeActiveDialog()
  }

  mountDialog() {
    this.removeActiveDialog()

    const fragment = this.dialogTemplateTarget.content.cloneNode(true)
    const dialog = fragment.querySelector("dialog.modal")
    if (!dialog) return

    dialog.dataset.avatarCropDialogSourceUrlValue = this.sourceObjectUrl
    dialog.dataset.avatarCropDialogFileNameValue = this.pendingFile?.name || "avatar.png"

    this.activeDialog = dialog
    this.boundApply = (event) => this.handleDialogApply(event)
    this.boundClosed = (event) => this.handleDialogClosed(event)

    dialog.addEventListener("avatar-crop-dialog:apply", this.boundApply)
    dialog.addEventListener("avatar-crop-dialog:closed", this.boundClosed)
    document.body.appendChild(dialog)
  }

  removeActiveDialog() {
    if (!this.activeDialog) return
    this.activeDialog.removeEventListener("avatar-crop-dialog:apply", this.boundApply)
    this.activeDialog.removeEventListener("avatar-crop-dialog:closed", this.boundClosed)
    this.activeDialog.remove()
    this.activeDialog = null
    this.boundApply = null
    this.boundClosed = null
  }

  openDialog() {
    if (!this.activeDialog || this.activeDialog.open) return
    this.activeDialog.showModal()
  }

  restorePreviousFiles() {
    this.replaceInputFiles(this.previousFiles || [])
  }

  restorePreviousState() {
    this.restorePreviousFiles()
    if (this.hasRemoveFlagTarget) {
      this.removeFlagTarget.value = this.previousRemoveFlag || "0"
    }
    if (this.hasAttachmentIdTarget) {
      this.attachmentIdTarget.value = this.previousAttachmentId || this.attachmentIdTarget.value
    }
    this.setAttachmentControlsEnabled(Boolean(this.previousAttachmentControlsEnabled))
    this.setRemoveButtonVisible(Boolean(this.previousCanRemove))
  }

  replaceInputFiles(files) {
    const dataTransfer = new DataTransfer()
    files.forEach((file) => dataTransfer.items.add(file))
    this.inputTarget.files = dataTransfer.files
  }

  removeAvatar(event) {
    event.preventDefault()
    event.stopPropagation()

    const hasAttachmentToDestroy = this.setAttachmentIdFlag(true)
    this.setRemoveFlag(hasAttachmentToDestroy)
    this.setAttachmentControlsEnabled(hasAttachmentToDestroy)
    this.setRemoveButtonVisible(false)
    this.replaceInputFiles([])
    this.restoreFallbackPreview()
  }

  updatePreview(file) {
    if (!this.hasPreviewTarget) return

    this.cleanupPreviewObjectUrl()
    this.previewObjectUrl = URL.createObjectURL(file)
    const previewUrl = this.previewObjectUrl

    const currentAvatar = this.previewTarget.firstElementChild
    if (!currentAvatar) return

    if (currentAvatar.tagName === "IMG") {
      currentAvatar.src = previewUrl
      return
    }

    const previewImage = document.createElement("img")
    previewImage.id = currentAvatar.id || "avatar-preview"
    previewImage.className = currentAvatar.className
    previewImage.src = previewUrl
    previewImage.alt = ""
    this.previewTarget.replaceChildren(previewImage)
  }

  cleanupSourceObjectUrl() {
    if (!this.sourceObjectUrl) return
    URL.revokeObjectURL(this.sourceObjectUrl)
    this.sourceObjectUrl = null
  }

  cleanupPreviewObjectUrl() {
    if (!this.previewObjectUrl) return
    URL.revokeObjectURL(this.previewObjectUrl)
    this.previewObjectUrl = null
  }

  setRemoveFlag(value) {
    if (!this.hasRemoveFlagTarget) return
    this.removeFlagTarget.value = value ? "1" : "0"
  }

  setAttachmentIdFlag(removing) {
    if (!this.hasAttachmentIdTarget) return false
    if (removing) {
      if (!this.attachmentIdTarget.value && this.previousAttachmentId) {
        this.attachmentIdTarget.value = this.previousAttachmentId
      }
      return this.attachmentIdTarget.value !== ""
    }

    this.attachmentIdTarget.value = ""
    return false
  }

  setAttachmentControlsEnabled(value) {
    if (this.hasAttachmentIdTarget) {
      this.attachmentIdTarget.disabled = !value
    }
    if (this.hasRemoveFlagTarget) {
      this.removeFlagTarget.disabled = !value
    }
  }

  setRemoveButtonVisible(value) {
    if (!this.hasRemoveButtonTarget) return
    this.removeButtonTarget.classList.toggle("hidden", !value)
    this.removeButtonTarget.classList.toggle("flex", value)
  }

  restoreFallbackPreview() {
    if (!this.hasPreviewTarget || !this.hasFallbackTemplateTarget) return

    this.cleanupPreviewObjectUrl()
    const currentAvatar = this.previewTarget.firstElementChild
    const fallbackRoot = this.fallbackTemplateTarget.content.firstElementChild?.cloneNode(true)
    if (!fallbackRoot) return

    if (currentAvatar) {
      const hasExplicitSize = /\b[wh]-\d/.test(fallbackRoot.className || "")
      if (!hasExplicitSize) {
        fallbackRoot.className = currentAvatar.className
      }
      if (!fallbackRoot.id) {
        fallbackRoot.id = currentAvatar.id || "avatar-preview"
      }
    }

    this.previewTarget.replaceChildren(fallbackRoot)
  }
}
