const modalFrame = () => document.querySelector("turbo-frame#modal")
const modalSnapshotStack = []

const requestHeaderValue = (headers, key) => {
  if (!headers) return null
  if (typeof headers.get === "function") return headers.get(key)
  return headers[key] || headers[key.toLowerCase()] || null
}

const isPrefetchRequest = (headers) => {
  const purpose = requestHeaderValue(headers, "Purpose") || requestHeaderValue(headers, "X-Sec-Purpose")
  return String(purpose || "").toLowerCase() === "prefetch"
}

const targetsModalFrameRequest = (event) => {
  const target = event?.target
  if (target instanceof Element) {
    if (target.tagName.toLowerCase() === "turbo-frame" && target.id === "modal") return true
  }

  const headers = event?.detail?.fetchOptions?.headers
  return requestHeaderValue(headers, "Turbo-Frame") === "modal"
}

const isModalFrameTarget = (event) => {
  const target = event?.target
  return target instanceof Element && target.closest("turbo-frame#modal")
}

export const closeAppModal = () => {
  const frame = modalFrame()
  const dialog = frame?.querySelector("dialog[data-app-modal='true']")

  if (!frame || !dialog) {
    modalSnapshotStack.length = 0
    frame?.removeAttribute("src")
    frame && (frame.innerHTML = "")
    return Promise.resolve()
  }

  return new Promise((resolve) => {
    let finished = false

    const finish = () => {
      if (finished) return
      finished = true
      resolve()
    }

    frame.addEventListener("app-modal:closed", finish, { once: true })
    dialog.dispatchEvent(new CustomEvent("app-modal:close", { bubbles: true }))
    setTimeout(finish, 250)
  })
}

export const popAppModalSnapshot = (frame) => {
  let snapshot = modalSnapshotStack.pop()
  while (snapshot && snapshot === frame.innerHTML) {
    snapshot = modalSnapshotStack.pop()
  }
  if (!snapshot) return false

  frame.dataset.appModalReplacing = "true"
  frame.removeAttribute("src")
  frame.innerHTML = snapshot

  // Snapshot can already contain an `open` dialog; disable transitions immediately
  // to avoid a one-frame backdrop flash before Stimulus reconnects.
  const dialog = frame.querySelector("dialog[data-app-modal='true']")
  if (dialog) {
    dialog.dataset.appModalTransitionBackup = dialog.style.transition || ""
    dialog.style.transition = "none"
    const box = dialog.querySelector(".modal-box")
    if (box) {
      box.dataset.appModalTransitionBackup = box.style.transition || ""
      box.style.transition = "none"
    }
  }
  return true
}

export const clearAppModalSnapshots = () => {
  modalSnapshotStack.length = 0
}

export const installAppModal = () => {
  document.addEventListener("turbo:before-frame-render", (event) => {
    if (!isModalFrameTarget(event)) return

    const frame = event.target
    if (!(frame instanceof Element)) return

    const hasCurrentModal = frame.querySelector("dialog[data-app-modal='true']") !== null
    const hasIncomingModal = event.detail?.newFrame?.querySelector?.("dialog[data-app-modal='true']") !== null
    if (!hasCurrentModal || !hasIncomingModal) return

    frame.dataset.appModalReplacing = "true"
  })

  document.addEventListener("turbo:before-fetch-request", (event) => {
    if (!targetsModalFrameRequest(event)) return

    const frame = modalFrame()
    if (!(frame instanceof Element)) return

    const headers = event.detail?.fetchOptions?.headers
    if (isPrefetchRequest(headers)) return

    const method = String(event.detail?.fetchOptions?.method || "GET").toUpperCase()
    if (method !== "GET") {
      // Mutating requests inside modal flow (e.g. DELETE via data-turbo-method)
      // can redirect to a fresh modal state; stale GET snapshots must not be restored.
      clearAppModalSnapshots()
      return
    }

    const dialog = frame.querySelector("dialog[data-app-modal='true']")
    if (!dialog) return

    frame.dataset.appModalReplacing = "true"
    const snapshot = frame.innerHTML
    const lastSnapshot = modalSnapshotStack[modalSnapshotStack.length - 1]
    if (snapshot !== lastSnapshot) {
      modalSnapshotStack.push(snapshot)
    }
  })

  document.addEventListener("turbo:before-fetch-response", (event) => {
    if (!targetsModalFrameRequest(event)) return

    const response = event.detail?.fetchResponse?.response
    if (!response) return
    if (!response.redirected) return

    clearAppModalSnapshots()
  })

  document.addEventListener("turbo:frame-missing", async (event) => {
    if (!isModalFrameTarget(event)) return

    event.preventDefault()

    const responseUrl = event.detail?.response?.url || window.location.href
    modalSnapshotStack.length = 0
    await closeAppModal()
    Turbo.visit(responseUrl, { action: "replace" })
  })

  document.addEventListener("turbo:before-cache", () => {
    modalSnapshotStack.length = 0
    const frame = modalFrame()
    if (!frame) return

    frame.removeAttribute("src")
    frame.innerHTML = ""
  })
}
