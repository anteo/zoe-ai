import {Idiomorph} from "idiomorph"

/*
 * UTM redirect workaround (Rails + Turbo + UltimateTurboModal + DaisyUI).
 *
 * Why this exists:
 * - First modal save after hard refresh could miss smooth redirect behavior.
 * - Symptoms: fallback-like full visit behavior, stuck modal close promise,
 *   missing modal frame/state cleanup, next modal opening as full HTML page.
 *
 * What this fix does:
 * - Intercepts redirected modal responses at `turbo:before-fetch-response`.
 * - Same-path redirect: Idiomorph morphs page behind modal, then closes/cleans modal.
 * - Cross-page redirect: closes/cleans modal, then Turbo.visit replace.
 * - Defensive cleanup restores baseline modal state and recreates `turbo-frame#modal` if missing.
 *
 * What should be fixed in UTM upstream (so this can be removed):
 * 1) Redirect handling should cover `before-fetch-response` + modal descendants
 *    (not only frame-id-specific `frame-missing` paths).
 * 2) `hideModalWithPromise` should be fail-safe and always resolve (timeout fallback).
 * 3) Close cleanup should always restore invariants:
 *    - no stale dialog nodes
 *    - history flags reset
 *    - modal frame placeholder present for next open.
 */
export const installUtmRedirectFix = () => {
  const isModalFrameTarget = (event) => {
    const target = event?.target
    if (!(target instanceof Element)) return false

    if (
        target.tagName.toLowerCase() === "turbo-frame" &&
        (target.id === "modal" || target.id === "modal-inner")
    ) {
      return true
    }

    return !!target.closest("turbo-frame#modal, turbo-frame#modal-inner")
  }

  const isSamePageUrl = (url1, url2) => {
    try {
      const a = new URL(url1, window.location.origin)
      const b = new URL(url2, window.location.origin)
      return a.pathname === b.pathname
    } catch (_) {
      return false
    }
  }

  const morphPageBehindModal = (html) => {
    const doc = new DOMParser().parseFromString(html, "text/html")
    Idiomorph.morph(document.body, doc.body, {
      morphStyle: "innerHTML",
      ignoreActiveValue: true,
      callbacks: {
        beforeNodeMorphed: (oldNode) => {
          if (oldNode.id === "modal-container") return false
          if (oldNode.tagName?.toLowerCase() === "turbo-frame" &&
              (oldNode.id === "modal" || oldNode.id === "modal-inner")) return false
          return true
        }
      }
    })
  }

  const closeModalIfPresent = async () => {
    const forceCleanupModalArtifacts = () => {
      document.querySelectorAll("dialog#modal-container, dialog.drawer-container").forEach((dialog) => {
        try {
          dialog.close()
        } catch (_) {
        }
        dialog.remove()
      })

      let modalFrame = document.querySelector("turbo-frame#modal")
      if (modalFrame) {
        try {
          modalFrame.removeAttribute("src")
        } catch (_) {
        }
        try {
          modalFrame.innerHTML = ""
        } catch (_) {
        }
      } else {
        modalFrame = document.createElement("turbo-frame")
        modalFrame.id = "modal"
        document.body.appendChild(modalFrame)
      }

      document.body.removeAttribute("data-turbo-modal-history-advanced")
      window.modal = undefined
    }

    if (window.modal?.hideModalWithPromise) {
      try {
        let resolved = false
        await Promise.race([
          window.modal.hideModalWithPromise({skipHistoryBack: true}).then(() => {
            resolved = true
          }),
          new Promise((resolve) => setTimeout(resolve, 500))
        ])

        if (!resolved) forceCleanupModalArtifacts()
      } catch (_) {
      }
      forceCleanupModalArtifacts()
      return
    }

    forceCleanupModalArtifacts()
  }

  document.addEventListener(
      "turbo:before-fetch-response",
      async (event) => {
        if (!isModalFrameTarget(event)) return

        const fetchResponse = event.detail?.fetchResponse
        const response = fetchResponse?.response
        if (!response?.redirected) return

        event.preventDefault()
        event.stopImmediatePropagation()

        const redirectUrl = response.url

        if (isSamePageUrl(window.location.href, redirectUrl)) {
          try {
            const html = await fetchResponse.responseHTML
            if (!html) throw new Error("Missing redirected HTML")
            morphPageBehindModal(html)
            if (redirectUrl !== window.location.href) {
              history.replaceState({}, "", redirectUrl)
            }
            await closeModalIfPresent()
            return
          } catch (_) {
          }
        }

        await closeModalIfPresent()
        Turbo.cache?.exemptPageFromPreview?.()
        Turbo.cache?.clear?.()
        Turbo.visit(redirectUrl, {action: "replace"})
      },
      true
  )
}
