import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output"]

  connect() {
    console.log("Hello controller connected")
    this.outputTarget.textContent = "Hello from Stimulus!"
  }
}