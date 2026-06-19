import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "icon", "modeField", "tooltip"]
  static values = {
    analyserFftSize: {type: Number, default: 2048},
    continuousTooltip: String,
    manualTooltip: String,
    mode: {type: String, default: "off"},
    offTooltip: String,
    silenceDelayMs: {type: Number, default: 900},
    silenceRmsThreshold: {type: Number, default: 0.018},
    transcriptionUrl: String
  }

  connect() {
    this.handleWindowBlur = this.handleWindowBlur.bind(this)
    this.handleWindowKeyDown = this.handleWindowKeyDown.bind(this)
    this.handleWindowKeyUp = this.handleWindowKeyUp.bind(this)
    this.handleVisibilityChange = this.handleVisibilityChange.bind(this)

    this.modeValue = this.normalizeMode(this.modeValue)
    this.clearVoiceError()
    this.registerWindowListeners()
    this.applyState()
    this.refreshVoiceSession()
  }

  disconnect() {
    this.unregisterWindowListeners()
    this.stopVoiceSession()
  }

  handleTtsPlaybackStarted() {
    this.ttsPlaybackActive = true
    this.voiceQueue = []
    this.voiceLastSoundAt = null

    if (this.manualCaptureActive) {
      this.endManualCapture({discard: true})
    } else if (this.voiceSpeaking) {
      this.voiceSpeaking = false
      this.applyListeningGlow()
    }

    this.stopVoiceCapture(this.voiceRunId, {discard: true})
  }

  handleTtsPlaybackStopped() {
    this.ttsPlaybackActive = false
    this.voiceLastSoundAt = null
  }

  cycleMode() {
    const modes = ["off", "manual", "continuous"]
    const currentIndex = modes.indexOf(this.modeValue)
    const nextMode = modes[(currentIndex + 1 + modes.length) % modes.length]
    this.setMode(nextMode)
  }

  setMode(value) {
    const nextMode = this.normalizeMode(value)
    const previousMode = this.modeValue

    if (previousMode === nextMode) return

    if (this.manualCaptureActive && nextMode !== "manual") {
      this.endManualCapture()
    }

    this.modeValue = nextMode

    if (nextMode === "off") {
      this.clearVoiceError()
    }

    this.applyState()
    this.refreshVoiceSession()
  }

  applyState() {
    if (!this.hasButtonTarget || !this.hasIconTarget) return

    const isOff = this.modeValue === "off"
    const isManual = this.modeValue === "manual"
    const isContinuous = this.modeValue === "continuous"

    this.buttonTarget.classList.toggle("btn-ghost", true)
    this.buttonTarget.classList.toggle("opacity-50", isOff)

    this.iconTarget.classList.toggle("icon-[lucide--mic-off]", isOff)
    this.iconTarget.classList.toggle("icon-[lucide--mic]", isManual)
    this.iconTarget.classList.toggle("icon-[lucide--audio-lines]", isContinuous)

    if (this.hasModeFieldTarget) {
      this.modeFieldTarget.value = this.modeValue
    }

    this.buttonTarget.setAttribute("aria-label", this.currentTooltip())
    this.applyVoiceErrorState()
    this.applyListeningGlow()
  }

  clearVoiceError() {
    if (this.voiceErrorTimer) {
      clearTimeout(this.voiceErrorTimer)
      this.voiceErrorTimer = null
    }

    this.voiceErrorMessage = ""
    this.applyVoiceErrorState()
  }

  setVoiceError(message) {
    if (this.voiceErrorTimer) {
      clearTimeout(this.voiceErrorTimer)
      this.voiceErrorTimer = null
    }

    this.voiceErrorMessage = message || ""
    this.applyVoiceErrorState()

    if (this.voiceErrorMessage) {
      this.voiceErrorTimer = setTimeout(() => {
        this.voiceErrorTimer = null
        this.clearVoiceError()
      }, 2500)
    }
  }

  applyVoiceErrorState() {
    if (!this.hasTooltipTarget) return

    if (this.voiceErrorMessage) {
      this.applyTooltip(this.voiceErrorMessage)
      this.tooltipTarget.dispatchEvent(new CustomEvent("floating-tooltip:show", {
        bubbles: false,
        detail: {
          text: this.voiceErrorMessage,
          variant: "error"
        }
      }))
      return
    }

    this.applyTooltip(this.currentTooltip())
    this.tooltipTarget.dispatchEvent(new CustomEvent("floating-tooltip:hide", {bubbles: false}))
    this.tooltipTarget.dispatchEvent(new CustomEvent("floating-tooltip:update", {
      bubbles: false,
      detail: {
        text: this.currentTooltip(),
        variant: "neutral"
      }
    }))
  }

  applyTooltip(text) {
    if (!this.hasTooltipTarget) return
    this.tooltipTarget.dataset.floatingTooltipContentValue = text
  }

  applyListeningGlow() {
    if (!this.hasButtonTarget) return

    const active = Boolean(this.voiceSpeaking)
    this.buttonTarget.classList.toggle("animate-pulse", active)
    this.buttonTarget.classList.toggle("bg-primary", active)
    this.buttonTarget.classList.toggle("text-primary-content", active)
  }

  registerWindowListeners() {
    window.addEventListener("keydown", this.handleWindowKeyDown)
    window.addEventListener("keyup", this.handleWindowKeyUp)
    window.addEventListener("blur", this.handleWindowBlur)
    document.addEventListener("visibilitychange", this.handleVisibilityChange)
  }

  unregisterWindowListeners() {
    window.removeEventListener("keydown", this.handleWindowKeyDown)
    window.removeEventListener("keyup", this.handleWindowKeyUp)
    window.removeEventListener("blur", this.handleWindowBlur)
    document.removeEventListener("visibilitychange", this.handleVisibilityChange)
  }

  handleWindowKeyDown(event) {
    if (event.key !== "Alt" || event.repeat || this.modeValue !== "manual") return
    this.startManualCapture()
  }

  handleWindowKeyUp(event) {
    if (event.key !== "Alt" || !this.manualCaptureActive) return
    this.endManualCapture()
  }

  handleWindowBlur() {
    if (this.manualCaptureActive) {
      this.endManualCapture()
    }
  }

  handleVisibilityChange() {
    if (document.visibilityState === "hidden" && this.manualCaptureActive) {
      this.endManualCapture()
    }
  }

  async startManualCapture() {
    if (this.modeValue !== "manual" || this.ttsPlaybackActive || this.manualCaptureActive) return

    await this.ensureVoiceSession()
    if (!this.voiceActive || !this.voiceStream || this.modeValue !== "manual") return

    this.manualCaptureActive = true
    this.voiceSpeaking = true
    this.startVoiceCapture(this.voiceRunId)
    this.element.dispatchEvent(new CustomEvent("transcription:speech", {bubbles: true}))
    this.applyListeningGlow()
  }

  endManualCapture({discard = false} = {}) {
    if (!this.manualCaptureActive) return

    this.manualCaptureActive = false
    this.voiceSpeaking = false
    this.stopVoiceCapture(this.voiceRunId, {discard})
    this.applyListeningGlow()
  }

  refreshVoiceSession() {
    if (this.modeValue === "off") {
      this.stopVoiceSession()
      return
    }

    if (this.voiceActive) {
      this.syncActiveSessionMode()
      return
    }

    this.startVoiceSession()
  }

  async ensureVoiceSession() {
    if (this.voiceActive) return
    await this.startVoiceSession()
  }

  async startVoiceSession() {
    if (this.voiceActive || !this.hasTranscriptionUrlValue) return
    if (!window.navigator?.mediaDevices?.getUserMedia || typeof window.MediaRecorder === "undefined") {
      this.setMode("off")
      return
    }

    this.voiceRunId = (this.voiceRunId || 0) + 1
    const runId = this.voiceRunId
    this.voiceActive = true
    this.voiceSpeaking = false
    this.voiceLastSoundAt = null
    this.voiceQueue = []
    this.voiceChunks = []
    this.voiceRecorder = null
    this.voiceRecorderMimeType = ""
    this.voiceDiscardCurrentCapture = false
    this.voiceTranscribing = false

    try {
      this.voiceStream = await window.navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true
        }
      })

      if (runId !== this.voiceRunId) {
        this.stopVoiceStream()
        return
      }

      this.voiceAudioContext = new window.AudioContext()
      this.voiceAnalyser = this.voiceAudioContext.createAnalyser()
      this.voiceAnalyser.fftSize = this.analyserFftSizeValue
      this.voiceSource = this.voiceAudioContext.createMediaStreamSource(this.voiceStream)
      this.voiceSource.connect(this.voiceAnalyser)
      this.voiceBuffer = new Uint8Array(this.voiceAnalyser.fftSize)
      this.syncActiveSessionMode()
    } catch (_error) {
      this.setMode("off")
    }
  }

  stopVoiceSession() {
    this.voiceRunId = (this.voiceRunId || 0) + 1
    this.voiceActive = false
    this.voiceSpeaking = false
    this.voiceLastSoundAt = null
    this.voiceQueue = []
    this.voiceChunks = []
    this.voiceTranscribing = false
    this.manualCaptureActive = false

    if (this.voiceFrame) {
      window.cancelAnimationFrame(this.voiceFrame)
      this.voiceFrame = null
    }

    this.stopVoiceCapture(this.voiceRunId, {discard: true})
    this.stopVoiceStream()
    this.applyListeningGlow()
  }

  syncActiveSessionMode() {
    if (!this.voiceActive) return

    if (this.modeValue === "continuous") {
      if (!this.voiceFrame) {
        this.monitorVoice(this.voiceRunId)
      }
      return
    }

    if (this.voiceFrame) {
      window.cancelAnimationFrame(this.voiceFrame)
      this.voiceFrame = null
    }

    this.voiceLastSoundAt = null

    if (!this.manualCaptureActive) {
      this.voiceSpeaking = false
      this.stopVoiceCapture(this.voiceRunId)
      this.applyListeningGlow()
    }
  }

  startVoiceCapture(runId) {
    if (runId !== this.voiceRunId || !this.voiceStream || this.voiceRecorder) return

    const mimeType = this.preferredVoiceMimeType()
    this.voiceRecorder = mimeType
      ? new window.MediaRecorder(this.voiceStream, {mimeType})
      : new window.MediaRecorder(this.voiceStream)
    this.voiceRecorderMimeType = this.voiceRecorder.mimeType || mimeType || "audio/webm"
    this.voiceChunks = []
    this.voiceDiscardCurrentCapture = false

    this.voiceRecorder.addEventListener("dataavailable", (event) => {
      if (runId !== this.voiceRunId || event.data.size === 0 || this.voiceDiscardCurrentCapture) return
      this.voiceChunks.push(event.data)
    })

    this.voiceRecorder.addEventListener("stop", () => {
      if (runId !== this.voiceRunId) return

      const chunks = this.voiceChunks
      const discard = this.voiceDiscardCurrentCapture
      const mimeTypeForBlob = this.voiceRecorderMimeType || "audio/webm"

      this.voiceRecorder = null
      this.voiceRecorderMimeType = ""
      this.voiceChunks = []
      this.voiceDiscardCurrentCapture = false

      if (discard || chunks.length === 0) return

      this.voiceQueue.push({blob: new Blob(chunks, {type: mimeTypeForBlob}), runId})
      this.drainVoiceQueue()
    }, {once: true})

    this.voiceRecorder.addEventListener("error", () => this.stopVoiceSession(), {once: true})
    this.voiceRecorder.start()
  }

  stopVoiceCapture(runId, {discard = false} = {}) {
    if (!this.voiceRecorder) return

    this.voiceDiscardCurrentCapture = discard

    if (runId !== this.voiceRunId) {
      this.voiceRecorder = null
      this.voiceRecorderMimeType = ""
      this.voiceChunks = []
      this.voiceDiscardCurrentCapture = false
      return
    }

    if (this.voiceRecorder.state !== "inactive") {
      try {
        this.voiceRecorder.stop()
      } catch (_error) {
        this.voiceRecorder = null
        this.voiceRecorderMimeType = ""
        this.voiceChunks = []
        this.voiceDiscardCurrentCapture = false
      }
    }
  }

  stopVoiceStream() {
    if (this.voiceSource) {
      try {
        this.voiceSource.disconnect()
      } catch (_error) {
        // Ignore disconnect errors.
      }
      this.voiceSource = null
    }

    this.voiceAnalyser = null

    if (this.voiceAudioContext) {
      try {
        this.voiceAudioContext.close()
      } catch (_error) {
        // Ignore audio context shutdown errors.
      }
      this.voiceAudioContext = null
    }

    if (this.voiceStream) {
      this.voiceStream.getTracks().forEach((track) => track.stop())
      this.voiceStream = null
    }
  }

  monitorVoice(runId) {
    if (runId !== this.voiceRunId || !this.voiceAnalyser || this.modeValue !== "continuous") {
      this.voiceFrame = null
      return
    }

    if (this.ttsPlaybackActive) {
      if (this.voiceSpeaking) {
        this.voiceSpeaking = false
        this.applyListeningGlow()
      }

      this.stopVoiceCapture(runId, {discard: true})
      this.voiceLastSoundAt = null
      this.voiceFrame = window.requestAnimationFrame(() => this.monitorVoice(runId))
      return
    }

    this.voiceAnalyser.getByteTimeDomainData(this.voiceBuffer)
    const level = this.voiceBuffer.reduce((sum, sample) => {
      const normalized = (sample - 128) / 128
      return sum + normalized * normalized
    }, 0) / this.voiceBuffer.length
    const rms = Math.sqrt(level)
    const speaking = rms >= this.silenceRmsThresholdValue
    const now = Date.now()

    if (speaking) {
      if (!this.voiceSpeaking) {
        this.voiceSpeaking = true
        this.startVoiceCapture(runId)
        this.element.dispatchEvent(new CustomEvent("transcription:speech", {bubbles: true}))
        this.applyListeningGlow()
      }

      this.voiceLastSoundAt = now
    } else if (this.voiceSpeaking && this.voiceLastSoundAt && now - this.voiceLastSoundAt >= this.silenceDelayMsValue) {
      this.voiceSpeaking = false
      this.stopVoiceCapture(runId)
      this.applyListeningGlow()
    }

    this.voiceFrame = window.requestAnimationFrame(() => this.monitorVoice(runId))
  }

  async drainVoiceQueue() {
    if (this.voiceTranscribing) return

    this.voiceTranscribing = true
    try {
      while (this.voiceQueue.length > 0) {
        const item = this.voiceQueue.shift()
        if (!item || item.runId !== this.voiceRunId) continue

        const result = await this.transcribeVoiceBlob(item.blob, item.runId)
        if (result.error) {
          this.setVoiceError(result.error)
        } else {
          this.clearVoiceError()
        }

        if (result.text && item.runId === this.voiceRunId && this.modeValue !== "off") {
          this.element.dispatchEvent(new CustomEvent("transcription:transcribed", {
            bubbles: true,
            detail: {text: result.text}
          }))
        }
      }
    } finally {
      this.voiceTranscribing = false
    }
  }

  async transcribeVoiceBlob(blob, runId) {
    const formData = new FormData()
    formData.append("audio", blob, `voice-${Date.now()}.webm`)

    const response = await fetch(this.transcriptionUrlValue, {
      method: "POST",
      credentials: "same-origin",
      headers: {
        "X-CSRF-Token": this.csrfToken()
      },
      body: formData
    }).catch(() => null)

    if (!response || !response.ok || runId !== this.voiceRunId) {
      return {
        text: "",
        error: runId === this.voiceRunId ? await this.extractVoiceError(response) : ""
      }
    }

    const payload = await response.json().catch(() => null)
    return {text: payload?.text?.trim() || "", error: ""}
  }

  async extractVoiceError(response) {
    if (!response) return "transcription_failed"
    if (response.status === 400) return "missing_audio"

    const payload = await response.json().catch(() => null)
    return payload?.error
  }

  preferredVoiceMimeType() {
    const candidates = [
      "audio/webm;codecs=opus",
      "audio/webm",
      "audio/ogg;codecs=opus",
      "audio/ogg"
    ]

    return candidates.find((mimeType) => window.MediaRecorder.isTypeSupported(mimeType)) || ""
  }

  currentTooltip() {
    switch (this.modeValue) {
      case "manual":
        return this.manualTooltipValue
      case "continuous":
        return this.continuousTooltipValue
      default:
        return this.offTooltipValue
    }
  }

  normalizeMode(value) {
    return ["off", "manual", "continuous"].includes(value) ? value : "off"
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }
}
