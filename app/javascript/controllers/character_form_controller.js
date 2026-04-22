import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["avatarPreview", "nameInput", "instructions", "instructionInput", "instructionTemplate"]
  static values = { existingInstructions: Array }

  connect() {
    this.renderExistingInstructions()

    if (this.nameInputTarget.value.trim() === "") {
      this.nameInputTarget.focus()
    }
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
    if (!instructionItem) return

    const idInput = instructionItem.querySelector("input[name*='[id]']")
    const destroyInput = instructionItem.querySelector("input[name*='[_destroy]']")
    const hasPersistedInstruction = idInput && idInput.value.trim() !== ""

    if (hasPersistedInstruction && destroyInput) {
      destroyInput.value = "1"
      instructionItem.classList.add("hidden")
      return
    }

    instructionItem.remove()
  }

  addInstruction() {
    const content = this.instructionInputTarget.value.trim()
    if (!content) return
    const index = this.nextInstructionIndex
    this.nextInstructionIndex += 1

    this.appendInstruction({ content }, index)
    this.instructionInputTarget.value = ""
  }

  appendInstruction(instruction, index) {
    const fragment = this.instructionTemplateTarget.content.cloneNode(true)
    const contentInput = fragment.querySelector("input[name*='[content]']")
    if (!contentInput) return
    const idInput = fragment.querySelector("input[name*='[id]']")
    const destroyInput = fragment.querySelector("input[name*='[_destroy]']")

    contentInput.name = contentInput.name.replace("__INDEX__", index)
    contentInput.value = instruction.content || ""
    if (idInput) {
      idInput.name = idInput.name.replace("__INDEX__", index)
      idInput.value = instruction.id || ""
    }
    if (destroyInput) {
      destroyInput.name = destroyInput.name.replace("__INDEX__", index)
      destroyInput.value = "0"
    }
    this.instructionsTarget.appendChild(fragment)
  }

  renderExistingInstructions() {
    if (!this.hasInstructionsTarget || !this.hasInstructionTemplateTarget) return

    const instructions = this.hasExistingInstructionsValue ? this.existingInstructionsValue : []
    this.instructionsTarget.innerHTML = ""
    instructions.forEach((instruction, index) => {
      this.appendInstruction(instruction, index)
    })
    this.nextInstructionIndex = instructions.length
  }
}
