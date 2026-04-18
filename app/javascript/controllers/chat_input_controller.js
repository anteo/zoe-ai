import {Controller} from "@hotwired/stimulus"
import {createChatSubscription} from "../channels/chat_channel"

let memorizeMode = true

export default class extends Controller {
  static targets = ["attachmentsPreview", "attachmentTemplate", "textInput", "fileInput", "sendButton", "memorizeButton", "memorizeField", "memorizeIcon", "memorizeLabel"]
  static values = {
    chatId: Number
  }

  selectedFiles = []

  connect() {
    if (this.textInputTarget) {
      this.textInputTarget.focus()

      // Debounce timer for typing detection
      this.typingTimer = null
      this.typingDelay = 1000 // ms
      this.hasTyped = false
    }

    this.updateSendButton()
    this.applyMemorizeState()

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

  toggleMemorize() {
    memorizeMode = !memorizeMode
    this.applyMemorizeState()
  }

  applyMemorizeState() {
    if (!this.hasMemorizeButtonTarget || !this.hasMemorizeFieldTarget) return
    this.memorizeFieldTarget.value = memorizeMode ? "true" : "false"
    this.memorizeButtonTarget.classList.toggle("opacity-40", !memorizeMode)
    this.memorizeIconTarget.classList.toggle("icon-[lucide--bookmark]", memorizeMode)
    this.memorizeIconTarget.classList.toggle("icon-[lucide--bookmark-off]", !memorizeMode)
    if (this.hasMemorizeLabelTarget) {
      this.memorizeLabelTarget.textContent = memorizeMode
        ? this.memorizeLabelTarget.dataset.labelOn
        : this.memorizeLabelTarget.dataset.labelOff
    }
  }

  subscribeToChatChannel() {
    if (!this.chatIdValue) return

    this.subscription = createChatSubscription(this.chatIdValue)
  }

  handleTyping() {
    if (!this.subscription) {
      return
    }

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

  handleInput(event) {
    this.handleTyping()
    this.autoResize(event)
    this.updateSendButton()
  }

  handleKeydown(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault()
      if (this.hasContent()) {
        event.target.closest('form').requestSubmit()
      }
    }
  }

  handleSubmit(event) {
    if (!this.hasContent()) {
      event.preventDefault()
    }
  }

  hasContent() {
    const text = this.textInputTarget.value.trim()
    return text.length > 0 || this.selectedFiles.length > 0
  }

  updateSendButton() {
    if (!this.hasSendButtonTarget) return
    const active = this.hasContent()
    this.sendButtonTarget.classList.toggle("btn-default", !active)
    this.sendButtonTarget.classList.toggle("btn-success", active)
  }

  autoResize(event) {
    const el = event.target
    el.style.height = 'auto'
    el.style.height = Math.min(el.scrollHeight, 128) + 'px'
  }

  async displayAttachments(event) {
    const newFiles = Array.from(event.target.files)
    this.selectedFiles = [...this.selectedFiles, ...newFiles]
    this.syncFileInput()
    await this.renderAttachments()
    this.updateSendButton()
  }

  async removeAttachment(event) {
    const card = event.currentTarget.closest("[data-attachment-index]")
    const index = parseInt(card.dataset.attachmentIndex)
    this.selectedFiles.splice(index, 1)
    this.syncFileInput()
    await this.renderAttachments()
    this.updateSendButton()
  }

  syncFileInput() {
    const dt = new DataTransfer()
    this.selectedFiles.forEach(f => dt.items.add(f))
    this.fileInputTarget.files = dt.files
  }

  async renderAttachments() {
    const preview = this.attachmentsPreviewTarget
    preview.innerHTML = ""

    if (this.selectedFiles.length === 0) {
      preview.classList.add("hidden")
      return
    }

    preview.classList.remove("hidden")

    for (let i = 0; i < this.selectedFiles.length; i++) {
      const file = this.selectedFiles[i]
      const clone = this.attachmentTemplateTarget.content.cloneNode(true)
      const wrapper = clone.querySelector("[data-attachment-index]")
      wrapper.dataset.attachmentIndex = i.toString()
      const contentEl = clone.querySelector("[data-attachment-content]")

      if (file.type.startsWith("image/")) {
        const img = document.createElement("img")
        img.src = URL.createObjectURL(file)
        img.className = "w-20 h-20 object-cover block"
        img.alt = file.name
        contentEl.appendChild(img)
      } else if (this.isTextFile(file)) {
        const text = await file.text()
        const excerpt = text.slice(0, 250)
        contentEl.innerHTML = `
          <div class="w-48 h-16 p-2 text-xs font-mono overflow-hidden leading-tight opacity-70 whitespace-pre">${this.escapeHtml(excerpt)}</div>
          <div class="px-2 py-1 text-xs truncate border-t border-base-content/10 bg-base-300/40">${this.escapeHtml(file.name)}</div>
        `
      } else {
        contentEl.className = "flex flex-col items-center justify-center w-24 h-20 p-2"
        contentEl.innerHTML = `
          <span class="icon-[lucide--file] w-8 h-8 opacity-60"></span>
          <span class="text-xs text-center truncate w-full">${this.escapeHtml(file.name)}</span>
          <span class="text-xs opacity-50">${this.formatFileSize(file.size)}</span>
        `
      }

      preview.appendChild(clone)
    }
  }

  isTextFile(file) {
    if (file.type.startsWith("text/")) return true
    return /\.(txt|md|js|ts|jsx|tsx|rb|py|json|yaml|yml|csv|html|css|xml|sh|bash|zsh|swift|kt|java|cpp|c|h|cs|go|rs|php)$/i.test(file.name)
  }

  escapeHtml(str) {
    const div = document.createElement("div")
    div.appendChild(document.createTextNode(str))
    return div.innerHTML
  }

  formatFileSize(bytes) {
    if (bytes === 0) return "0 Bytes"
    const k = 1024
    const sizes = ["Bytes", "KB", "MB", "GB"]
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + " " + sizes[i]
  }
}
