import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static outlets = ["admin-console-modal"]

  open() {
    if (this.hasAdminConsoleModalOutlet) this.adminConsoleModalOutlet.open()
  }
}
