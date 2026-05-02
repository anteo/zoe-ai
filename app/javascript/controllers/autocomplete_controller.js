import { Autocomplete } from "stimulus-autocomplete"

export default class extends Autocomplete {
  connect() {
    super.connect()
    this.onInputActivate = this.onInputActivate.bind(this)
    this.onInputClick = this.onInputClick.bind(this)
    this.inputTarget.addEventListener("focus", this.onInputActivate)
    this.inputTarget.addEventListener("click", this.onInputActivate)
    this.inputTarget.addEventListener("click", this.onInputClick)
  }

  disconnect() {
    this.inputTarget.removeEventListener("focus", this.onInputActivate)
    this.inputTarget.removeEventListener("click", this.onInputActivate)
    this.inputTarget.removeEventListener("click", this.onInputClick)
    super.disconnect()
  }

  select(target) {
    const previouslySelected = this.selectedOption

    if (previouslySelected) {
      previouslySelected.removeAttribute("aria-selected")
      this.selectionNode(previouslySelected).classList.remove("menu-active")
    }

    target.setAttribute("aria-selected", "true")
    this.selectionNode(target).classList.add("menu-active")
    this.inputTarget.setAttribute("aria-activedescendant", target.id)
    target.scrollIntoView({ behavior: "auto", block: "nearest" })
  }

  commit(selected) {
    this.suppressAutoOpenUntil = Date.now() + 200
    super.commit(selected)
  }

  selectionNode(optionElement) {
    return optionElement.firstElementChild || optionElement
  }

  onInputActivate() {
    if (!this.hasUrlValue) return
    if (Date.now() < (this.suppressAutoOpenUntil || 0)) return

    this.fetchResults("")
  }

  onInputClick() {
    this.inputTarget.select()
  }
}
