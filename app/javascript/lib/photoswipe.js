import PhotoSwipeLightbox from "photoswipe/lightbox"

export function createPhotoSwipeLightbox(gallery) {
  const appendToEl = gallery.closest("dialog") || document.body

  const lightbox = new PhotoSwipeLightbox({
    appendToEl,
    gallery,
    children: ".lightbox-link",
    showHideAnimationType: 'fade',
    pswpModule: () => import("photoswipe")
  })

  lightbox.on("keydown", ({ originalEvent }) => {
    if (originalEvent.key === "Escape") {
      originalEvent.stopPropagation()
    }
  })

  lightbox.init()

  return lightbox
}
