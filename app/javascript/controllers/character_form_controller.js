import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["avatarPreview", "nameInput", "instructions", "instructionInput", "instructionTemplate", "instructionsCountBadge", "imagesCountBadge", "tab", "panel", "imagePicker", "images", "imageCardTemplate", "newImageInputs"]
  static values = {currentSection: String, existingInstructions: Array}

  connect() {
    this.activateSection(this.currentSectionValue || this.defaultSection)

    if (this.hasNameInputTarget && this.nameInputTarget.value.trim() === "") {
      this.nameInputTarget.focus()
    }
  }

  disconnect() {
    if (!this.avatarPreviewObjectUrl) return
    URL.revokeObjectURL(this.avatarPreviewObjectUrl)
    this.avatarPreviewObjectUrl = null
  }

  instructionsTargetConnected() {
    this.renderExistingInstructions()
  }

  instructionTemplateTargetConnected() {
    this.renderExistingInstructions()
  }

  imagesTargetConnected() {
    this.imagesInitialized = false
    this.initializeImageCards()
  }

  imageCardTemplateTargetConnected() {
    this.initializeImageCards()
  }

  existingInstructionsValueChanged() {
    this.instructionsInitialized = false
    this.renderExistingInstructions()
  }

  showSection(event) {
    event.preventDefault()
    this.activateSection(event.currentTarget.dataset.section)
  }

  handleAvatarChange(event) {
    const file = event.target.files[0]
    if (!file) return

    if (this.avatarPreviewObjectUrl) {
      URL.revokeObjectURL(this.avatarPreviewObjectUrl)
    }

    const previewUrl = URL.createObjectURL(file)
    this.avatarPreviewObjectUrl = previewUrl

    const currentAvatar = this.avatarPreviewTarget.querySelector("#character-avatar-preview") || this.avatarPreviewTarget.firstElementChild
    if (!currentAvatar) return

    if (currentAvatar.tagName === "IMG") {
      currentAvatar.src = previewUrl
      return
    }

    const previewImage = document.createElement("img")
    previewImage.id = currentAvatar.id || "character-avatar-preview"
    previewImage.className = currentAvatar.className
    previewImage.src = previewUrl
    previewImage.alt = this.hasNameInputTarget ? this.nameInputTarget.value.trim() : ""

    this.avatarPreviewTarget.replaceChildren(previewImage)
  }

  handleImagesChange(event) {
    this.initializeImageCards()

    const files = Array.from(event.target.files || [])
    if (files.length === 0) return

    files.forEach((file) => this.appendNewImage(file))

    event.target.value = ""
  }

  handleInstructionKeydown(event) {
    if (event.key !== "Enter" || event.shiftKey) return
    event.preventDefault()
    this.addInstruction()
  }

  handleSubmit() {
    this.addInstruction()
  }

  toggleImageRemoval(event) {
    event.preventDefault()

    const card = event.currentTarget.closest("[data-character-image-card]")
    if (!card) return

    const newImageIndex = card.dataset.newImageIndex
    if (newImageIndex) {
      this.removeNewImageCard(card, newImageIndex)
      return
    }

    const removeInput = card.querySelector("input[name*='[_destroy]']")
    if (!removeInput) return

    const shouldRemove = removeInput.value !== "1"
    removeInput.value = shouldRemove ? "1" : "0"

    card.classList.toggle("opacity-40", shouldRemove)
    this.updateImagesCountBadge()
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
      this.updateInstructionsCountBadge()
      return
    }

    instructionItem.remove()
    this.updateInstructionsCountBadge()
  }

  addInstruction() {
    const content = this.instructionInputTarget.value.trim()
    if (!content) return
    const index = this.nextInstructionIndex
    this.nextInstructionIndex += 1

    this.appendInstruction({content}, index)
    this.instructionInputTarget.value = ""
    this.instructionInputTarget.dispatchEvent(new Event("input", {bubbles: true}))
    this.updateInstructionsCountBadge()
  }

  appendInstruction(instruction, index) {
    const fragment = this.instructionTemplateTarget.content.cloneNode(true)
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
      destroyInput.value = "0"
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
    this.updateInstructionsCountBadge()
  }

  initializeImageCards() {
    if (!this.hasImagesTarget || !this.hasImageCardTemplateTarget) return
    if (this.currentSectionValue !== "images") return
    if (this.imagesInitialized) return

    const images = this.initialImages()
    this.imagesTarget.innerHTML = ""
    images.forEach((image) => {
      this.imagesTarget.appendChild(this.buildExistingImageCard(image))
    })

    this.nextNewImageIndex = images.length
    this.imagesInitialized = true
    this.updateImagesCountBadge()
  }

  initialImages() {
    const section = this.imagesTarget.closest("[data-existing-images-json]")
    if (!section) return []

    try {
      return JSON.parse(section.dataset.existingImagesJson || "[]")
    } catch (_) {
      return []
    }
  }

  buildExistingImageCard(image) {
    const card = this.buildImageCard({src: image.url, alt: image.filename, description: image.description})
    const idInput = card.querySelector("[data-role='id']")
    const destroyInput = card.querySelector("[data-role='destroy']")
    const descriptionInput = card.querySelector("[data-role='description']")
    if (!idInput || !destroyInput || !descriptionInput) return card

    const id = `${image.id}`
    this.applyFieldIndex(idInput, id)
    idInput.value = id

    this.applyFieldIndex(destroyInput, id)
    destroyInput.value = "0"

    this.applyFieldIndex(descriptionInput, id)
    descriptionInput.value = image.description || ""

    return card
  }

  appendNewImage(file) {
    if (!this.hasImagesTarget || !this.hasNewImageInputsTarget) return

    const index = this.nextNewImageIndex || 0
    this.nextNewImageIndex = index + 1

    const previewUrl = URL.createObjectURL(file)
    const card = this.buildImageCard({src: previewUrl, alt: file.name, description: ""})
    const idInput = card.querySelector("[data-role='id']")
    const destroyInput = card.querySelector("[data-role='destroy']")
    const descriptionInput = card.querySelector("[data-role='description']")

    if (idInput) idInput.removeAttribute("name")
    if (destroyInput) destroyInput.removeAttribute("name")

    if (descriptionInput) {
      descriptionInput.name = descriptionInput.dataset.newName
      this.applyFieldIndex(descriptionInput, index)
    }

    card.dataset.newImageIndex = `${index}`
    card.dataset.previewUrl = previewUrl

    const uploadInput = document.createElement("input")
    uploadInput.type = "file"
    uploadInput.className = "hidden"
    uploadInput.name = "character[images][]"
    uploadInput.dataset.newImageIndex = `${index}`

    const transfer = new DataTransfer()
    transfer.items.add(file)
    uploadInput.files = transfer.files

    this.newImageInputsTarget.appendChild(uploadInput)
    this.imagesTarget.appendChild(card)
    this.updateImagesCountBadge()
  }

  buildImageCard({src, alt, description}) {
    const fragment = this.imageCardTemplateTarget.content.cloneNode(true)
    const card = fragment.querySelector("[data-character-image-card]")
    if (!card) return document.createElement("article")

    const image = card.querySelector("img")
    if (image) {
      image.src = src
      image.alt = alt || ""
    }

    const descriptionInput = card.querySelector("[data-role='description']")
    if (descriptionInput) {
      descriptionInput.value = description || ""
    }

    return card
  }

  removeNewImageCard(card, index) {
    const uploadInput = this.newImageInputsTarget.querySelector(`input[data-new-image-index='${index}']`)
    if (uploadInput) {
      uploadInput.remove()
    }

    if (card.dataset.previewUrl) {
      URL.revokeObjectURL(card.dataset.previewUrl)
    }

    card.remove()
    this.updateImagesCountBadge()
  }

  applyFieldIndex(field, index) {
    if (!field?.name) return
    field.name = field.name.replace("__INDEX__", `${index}`)
  }

  activateSection(section) {
    if (!this.hasTabTarget || !this.hasPanelTarget) return

    const activeSection = section || this.defaultSection
    this.currentSectionValue = activeSection

    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.section === activeSection
      tab.classList.toggle("tab-active", active)
      tab.setAttribute("aria-selected", active ? "true" : "false")
    })

    this.panelTargets.forEach((panel) => {
      const active = panel.dataset.section === activeSection
      panel.classList.toggle("hidden", !active)
      // panel.classList.toggle("flex", active)
    })

    this.initializeImageCards()
  }

  get defaultSection() {
    return this.tabTargets[0]?.dataset.section
  }

  initialInstructions() {
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

  updateInstructionsCountBadge() {
    if (!this.hasInstructionsCountBadgeTarget || !this.hasInstructionsTarget) return

    this.instructionsCountBadgeTarget.textContent = this.instructionsTarget.querySelectorAll("li input[name*='[_destroy]'][value='0']").length
  }

  updateImagesCountBadge() {
    if (!this.hasImagesCountBadgeTarget || !this.hasImagesTarget) return

    const visibleCount = Array.from(this.imagesTarget.querySelectorAll("[data-character-image-card]"))
      .filter((card) => {
        if (card.dataset.newImageIndex) return true

        const removeInput = card.querySelector("input[name*='[_destroy]']")
        return !removeInput || removeInput.value !== "1"
      })
      .length

    this.imagesCountBadgeTarget.textContent = visibleCount
  }
}
