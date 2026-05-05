import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static values = {windowUrl: String}

  open(event) {
    if (!event.metaKey && !event.ctrlKey) return
    if (!this.hasWindowUrlValue) return

    event.preventDefault()
    window.open(this.windowUrlValue, "_blank", "noopener")
  }
}
