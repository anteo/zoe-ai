import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["instructions", "instructionInput", "instructionTemplate", "countBadge"]
  static values = {existingInstructions: Array}

  connect() {
    this.boundHandleSubmit = this.handleSubmit.bind(this)
    this.form = this.element.closest("form")
    this.form?.addEventListener("submit", this.boundHandleSubmit)
    this.instructionsInitialized = false
    this.renderExistingInstructions()
  }

  disconnect() {
    this.form?.removeEventListener("submit", this.boundHandleSubmit)
  }

  instructionsTargetConnected() {
    this.renderExistingInstructions()
  }

  instructionTemplateTargetConnected() {
    this.renderExistingInstructions()
  }

  existingInstructionsValueChanged() {
    this.instructionsInitialized = false
    this.renderExistingInstructions()
  }

  handleInstructionKeydown(event) {
    if (event.key !== "Enter" || event.shiftKey) return
    event.preventDefault()
    this.addInstruction()
  }

  handleSubmit() {
    this.addInstruction()
  }

  removeInstruction(event) {
    event.preventDefault()
    event.stopPropagation()

    const instructionItem = event.currentTarget.closest("li")
    if (!instructionItem) return

    const idInput = instructionItem.querySelector("input[name*='[id]']")
    const destroyInput = instructionItem.querySelector("input[name*='[_destroy]']")
    const hasPersistedInstruction = idInput && idInput.value.trim() !== ""

    if (hasPersistedInstruction && destroyInput) {
      destroyInput.value = "1"
      instructionItem.classList.add("hidden")
      this.updateCountBadge()
      return
    }

    instructionItem.remove()
    this.updateCountBadge()
  }

  addInstruction() {
    if (!this.hasInstructionInputTarget) return

    const content = this.instructionInputTarget.value.trim()
    if (!content) return

    const index = this.nextInstructionIndex
    this.nextInstructionIndex += 1

    this.appendInstruction({content}, index)
    this.instructionInputTarget.value = ""
    this.instructionInputTarget.dispatchEvent(new Event("input", {bubbles: true}))
    this.updateCountBadge()
  }

  appendInstruction(instruction, index) {
    if (!this.hasInstructionTemplateTarget || !this.hasInstructionsTarget) return

    const fragment = this.instructionTemplateTarget.content.cloneNode(true)
    const instructionItem = fragment.querySelector("li")
    const contentInput = fragment.querySelector("textarea[name*='[content]'], input[name*='[content]']")
    if (!contentInput) return

    const idInput = fragment.querySelector("input[name*='[id]']")
    const destroyInput = fragment.querySelector("input[name*='[_destroy]']")

    this.applyFieldIndex(contentInput, index)
    contentInput.value = instruction.content || ""

    if (idInput) {
      this.applyFieldIndex(idInput, index)
      idInput.value = instruction.id || ""
    }

    if (destroyInput) {
      this.applyFieldIndex(destroyInput, index)
      destroyInput.value = instruction._destroy || "0"
    }

    if (instructionItem && destroyInput?.value === "1") {
      instructionItem.classList.add("hidden")
    }

    this.instructionsTarget.appendChild(fragment)
  }

  renderExistingInstructions() {
    if (!this.hasInstructionsTarget || !this.hasInstructionTemplateTarget) return
    if (this.instructionsInitialized) return

    const instructions = this.initialInstructions()
    this.instructionsTarget.innerHTML = ""
    instructions.forEach((instruction, index) => {
      this.appendInstruction(instruction, index)
    })

    this.nextInstructionIndex = instructions.length
    this.instructionsInitialized = true
    this.updateCountBadge()
  }

  initialInstructions() {
    if (!this.hasInstructionsTarget) {
      return this.hasExistingInstructionsValue ? this.existingInstructionsValue : []
    }

    const section = this.instructionsTarget.closest("[data-existing-instructions-json]")
    if (!section) {
      return this.hasExistingInstructionsValue ? this.existingInstructionsValue : []
    }

    try {
      return JSON.parse(section.dataset.existingInstructionsJson || "[]")
    } catch (_) {
      return []
    }
  }

  updateCountBadge() {
    if (!this.hasCountBadgeTarget || !this.hasInstructionsTarget) return

    this.countBadgeTarget.textContent = this.instructionsTarget.querySelectorAll("li input[name*='[_destroy]'][value='0']").length
  }

  applyFieldIndex(field, index) {
    if (!field?.name) return
    field.name = field.name.replace("__INDEX__", `${index}`)
  }
}
