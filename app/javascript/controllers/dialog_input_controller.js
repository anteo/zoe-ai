import {Controller} from "@hotwired/stimulus"
import {createChatSubscription} from "../channels/chat_channel"

export default class extends Controller {
  static targets = ["attachmentsPreview", "attachmentTemplate", "textInput"]
  static values = {
    chatId: Number
  }

  connect() {
    if (this.textInputTarget) {
      // Add event listeners for typing detection
      this.textInputTarget.addEventListener('input', this.handleTyping.bind(this))
      this.textInputTarget.focus()

      // Debounce timer for typing detection
      this.typingTimer = null
      this.typingDelay = 1000 // ms
      this.hasTyped = false
    }

    // Subscribe to Action Cable channel for this chat
    this.subscribeToChatChannel()
  }

  disconnect() {
    if (this.textInputTarget) {
      this.textInputTarget.removeEventListener('input', this.handleTyping)
    }
    if (this.typingTimer) {
      clearTimeout(this.typingTimer)
    }
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  subscribeToChatChannel() {
    if (!this.chatIdValue) return

    this.subscription = createChatSubscription(this.chatIdValue)
  }

  handleTyping(event) {

    // Only trigger on first typing event
    if (!this.hasTyped) {
      this.hasTyped = true
      this.subscription.userTyping()
    }

    // Reset timer for continuous typing
    if (this.typingTimer) {
      clearTimeout(this.typingTimer)
    }

    this.typingTimer = setTimeout(() => {
      this.hasTyped = false
    }, this.typingDelay)
  }

  displayAttachments(event) {
    const files = event.target.files
    const preview = this.attachmentsPreviewTarget

    if (files.length === 0) {
      preview.classList.add("hidden")
      preview.innerHTML = ""
      return
    }

    preview.innerHTML = ""
    preview.classList.remove("hidden")

    Array.from(files).forEach(file => {
      const template = this.attachmentTemplateTarget
      const clone = template.content.cloneNode(true)
      const fileElement = clone.querySelector("div")

      const fileNameElement = fileElement.querySelector("[data-file-name]")
      const fileSizeElement = fileElement.querySelector("[data-file-size]")

      fileNameElement.textContent = file.name
      fileSizeElement.textContent = `(${this.formatFileSize(file.size)})`

      preview.appendChild(fileElement)
    })
  }

  formatFileSize(bytes) {
    if (bytes === 0) return "0 Bytes"
    const k = 1024
    const sizes = ["Bytes", "KB", "MB", "GB"]
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + " " + sizes[i]
  }
}