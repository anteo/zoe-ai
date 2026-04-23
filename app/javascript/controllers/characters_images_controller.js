import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["images", "imageCardTemplate", "newImageInputs", "countBadge"]

  connect() {
    this.imagesInitialized = false
    this.initializeImageCards()
  }

  disconnect() {
    if (!this.hasImagesTarget) return

    this.imagesTarget.querySelectorAll("[data-character-image-card][data-preview-url]").forEach((card) => {
      URL.revokeObjectURL(card.dataset.previewUrl)
    })
  }

  imagesTargetConnected() {
    this.imagesInitialized = false
    this.initializeImageCards()
  }

  imageCardTemplateTargetConnected() {
    this.initializeImageCards()
  }

  handleImagesChange(event) {
    this.initializeImageCards()

    const files = Array.from(event.target.files || [])
    if (files.length === 0) return

    files.forEach((file) => this.appendNewImage(file))
    event.target.value = ""
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
    this.updateCountBadge()
  }

  initializeImageCards() {
    if (!this.hasImagesTarget || !this.hasImageCardTemplateTarget) return
    if (this.imagesInitialized) return

    const images = this.initialImages()
    this.imagesTarget.innerHTML = ""
    images.forEach((image) => {
      this.imagesTarget.appendChild(this.buildExistingImageCard(image))
    })

    this.nextNewImageIndex = images.length
    this.imagesInitialized = true
    this.updateCountBadge()
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
    this.updateCountBadge()
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
    const uploadInput = this.hasNewImageInputsTarget ? this.newImageInputsTarget.querySelector(`input[data-new-image-index='${index}']`) : null
    if (uploadInput) {
      uploadInput.remove()
    }

    if (card.dataset.previewUrl) {
      URL.revokeObjectURL(card.dataset.previewUrl)
    }

    card.remove()
    this.updateCountBadge()
  }

  updateCountBadge() {
    if (!this.hasCountBadgeTarget || !this.hasImagesTarget) return

    const visibleCount = Array.from(this.imagesTarget.querySelectorAll("[data-character-image-card]"))
      .filter((card) => {
        if (card.dataset.newImageIndex) return true

        const removeInput = card.querySelector("input[name*='[_destroy]']")
        return !removeInput || removeInput.value !== "1"
      })
      .length

    this.countBadgeTarget.textContent = visibleCount
  }

  applyFieldIndex(field, index) {
    if (!field?.name) return
    field.name = field.name.replace("__INDEX__", `${index}`)
  }
}
