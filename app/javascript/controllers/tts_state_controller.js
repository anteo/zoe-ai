import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "field", "icon"]
  static values = {
    mode: { type: Boolean, default: false },
    storageKey: { type: String, default: "zoe:tts-enabled" }
  }

  connect() {
    this.loadPersistedMode()
    this.applyState()
    this.sync()
  }

  toggle() {
    this.modeValue = !this.modeValue
    this.persistMode()
    this.applyState()
    this.sync()

    if (!this.modeValue) {
      this.element.dispatchEvent(new CustomEvent("tts-state:disabled", { bubbles: true }))
    }
  }

  sync() {
    this.loadPersistedMode()
    const value = this.modeValue ? "true" : "false"
    this.fieldTargets.forEach((field) => {
      if ("value" in field) {
        field.value = value
      } else {
        field.dataset.ttsEnabled = value
      }
    })

    const hiddenInput = this.element.querySelector('input[name="message[tts_enabled]"]')
    if (hiddenInput) {
      hiddenInput.value = value
    }
  }

  applyState() {
    if (!this.hasButtonTarget || !this.hasIconTarget) return

    this.buttonTarget.classList.toggle("btn-ghost", !this.modeValue)
    this.buttonTarget.classList.toggle("btn-accent", this.modeValue)
    this.buttonTarget.classList.toggle("text-accent-content", this.modeValue)
    this.buttonTarget.classList.toggle("opacity-50", !this.modeValue)
    this.iconTarget.classList.toggle("icon-[lucide--volume-2]", this.modeValue)
    this.iconTarget.classList.toggle("icon-[lucide--volume-x]", !this.modeValue)
  }

  loadPersistedMode() {
    try {
      const persisted = window.localStorage.getItem(this.ttsStorageKeyValue)
      if (persisted === "true" || persisted === "false") {
        this.modeValue = persisted === "true"
      }
    } catch (_error) {
      // Ignore storage access errors and keep the current default.
    }
  }

  persistMode() {
    try {
      window.localStorage.setItem(this.ttsStorageKeyValue, this.modeValue ? "true" : "false")
    } catch (_error) {
      // Ignore storage access errors.
    }
  }
}
