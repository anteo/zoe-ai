import { Controller } from "@hotwired/stimulus"
import { vistaView } from "vistaview"
import { download } from "vistaview/extensions/download.js"

export default class extends Controller {
  connect() {
    this.initVistaView()
  }

  disconnect() {
    if (this.vista) {
      this.vista.reset()
    }
  }

  initVistaView() {
    if (this.vista) {
      this.vista.reset()
      return
    }

    if (this.element.querySelectorAll(".lightbox-link").length === 0) {
      return
    }

    this.vista = vistaView({
      elements: ".lightbox-link",
      controls: {
        topRight: ["zoomIn", "zoomOut", "download", "close"]
      },
      extensions: [download()]
    })
  }
}
