import {Application} from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

// application.js
addEventListener("turbo:before-stream-render", (event) => {
  const originalRender = event.detail.render

  event.detail.render = function (streamElement) {
    originalRender(streamElement)
    document.dispatchEvent(new CustomEvent("turbo:after-stream-render", {
      detail: { action: streamElement.action, target: streamElement.target }
    }))
  }
})

export {application}
