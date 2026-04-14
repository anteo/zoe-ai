import {Controller} from "@hotwired/stimulus"
import {vistaView} from "vistaview"
import {download} from 'vistaview/extensions/download.js';

export default class extends Controller {
  connect() {
    this.scrollToLastMessage()
    // Use before-stream-render to capture state before DOM changes
    document.addEventListener("turbo:after-stream-render", this.scrollAfterRender)
    document.addEventListener("turbo:after-stream-render", this.initVistaView)
    this.initVistaView()
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.beforeStreamRender)
    document.removeEventListener("turbo:after-stream-render", this.scrollAfterRender)
    document.removeEventListener("turbo:after-stream-render", this.initVistaView)
  }

  scrollToLastMessage(behavior = "instant") {
    const container = this.element
    container.scrollTo({
      top: container.scrollHeight - container.clientHeight,
      behavior: behavior
    })
  }

  scrollAfterRender = () => {
    this.scrollToLastMessage("smooth")
  }

  initVistaView = () => {
    if (this.vista) {
      this.vista.reset()
    } else if (document.querySelectorAll('.lightbox-link').length > 0) {
      this.vista = vistaView({
        elements: '.lightbox-link',
        controls: {
          topRight: ['zoomIn', 'zoomOut', 'download', 'close'],
        },
        extensions: [download()],
        onOpen: (vv) => {
          console.log('VistaView opened', vv);
          const currentIndex = vv.getCurrentIndex();
          console.log('Current index:', currentIndex);
          // Log image dimensions if possible
          const images = vv.state?.children?.images;
          if (images && images.length) {
            images.forEach(img => {
              console.log('Image', img.index, 'width', img.state?.width, 'height', img.state?.height, 'initW', img.initW, 'initH', img.initH);
            });
          }
        },
        onImageView: (data, vv) => {
          console.log('Image view changed', data);
        },
      })
    }
  }
}
