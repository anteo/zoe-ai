import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["avatarPreview", "nameInput", "instructions", "instructionInput", "instructionTemplate"]
  static values = { existingInstructions: Array }

  connect() {
    this.renderExistingInstructions()
    this.nameInputTarget.focus()
  }

  existingInstructionsValueChanged() {
    this.renderExistingInstructions()
  }

  handleAvatarChange(event) {
    const file = event.target.files[0]
    if (!file) return

    this.avatarPreviewTarget.style.backgroundImage = `url(${URL.createObjectURL(file)})`
    this.avatarPreviewTarget.classList.add("bg-base-100")
    this.avatarPreviewTarget.innerHTML = ""
  }

  handleInstructionKeydown(event) {
    if (event.key !== "Enter") return
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
    instructionItem?.remove()
  }

  addInstruction() {
    const content = this.instructionInputTarget.value.trim()
    if (!content) return
    const index = this.nextInstructionIndex
    this.nextInstructionIndex += 1

    this.appendInstruction(content, index)
    this.instructionInputTarget.value = ""
  }

  appendInstruction(content, index) {
    const fragment = this.instructionTemplateTarget.content.cloneNode(true)
    const input = fragment.querySelector("input")
    if (!input) return

    input.name = input.name.replace("__INDEX__", index)
    input.value = content
    this.instructionsTarget.appendChild(fragment)
  }

  renderExistingInstructions() {
    if (!this.hasInstructionsTarget || !this.hasInstructionTemplateTarget) return

    const instructions = this.hasExistingInstructionsValue ? this.existingInstructionsValue : []
    this.instructionsTarget.innerHTML = ""
    instructions.forEach((content, index) => {
      this.appendInstruction(content, index)
    })
    this.nextInstructionIndex = instructions.length
  }
}
