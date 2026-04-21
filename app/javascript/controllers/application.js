import {Application} from "@hotwired/stimulus"
import { UltimateTurboModalController } from "ultimate_turbo_modal"

const application = Application.start()
application.register("modal", UltimateTurboModalController)

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

// application.js
const afterRenderEvent = new Event("turbo:after-stream-render");
addEventListener("turbo:before-stream-render", (event) => {
  const originalRender = event.detail.render

  event.detail.render = function (streamElement) {
    originalRender(streamElement)
    document.dispatchEvent(afterRenderEvent);
  }
})

export {application}