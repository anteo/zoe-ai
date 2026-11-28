// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"
import TC from "@rolemodel/turbo-confirm"
import "./channels"

Turbo.StreamActions.reload_agent_run = function () {
  const { frameId, url, agentConversationId } = this.dataset
  for (const slot of this.targetElements) {
    const frame = document.getElementById(frameId)
    if (frame) {
      if (frame.src) frame.reload()
      else frame.src = url
    } else {
      const pendingFrame = document.createElement("turbo-frame")
      pendingFrame.id = frameId
      pendingFrame.className = "block"
      pendingFrame.dataset.agentRunFrame = "true"
      pendingFrame.setAttribute("refresh", "morph")
      pendingFrame.src = url
      slot.append(pendingFrame)
    }
  }
  const dialog = document.querySelector('[data-agents="detail"] #agent-conversation-detail[src]')
  if (agentConversationId && dialog?.dataset.agentConversationId === agentConversationId) {
    dialog.reload()
  }
}

Turbo.StreamActions.close_modal = function () {
  const id = this.getAttribute("id")
  const modal = id ? document.getElementById(id) : document.querySelector("dialog[data-controller~='app-modal']:last-of-type")
  if (!modal) return

  modal.dispatchEvent(new CustomEvent("app-modal:close", {bubbles: true}))
}

TC.start({
  animationDuration: 200
})

// if ("serviceWorker" in navigator) {
//   window.addEventListener("load", () => {
//     navigator.serviceWorker.register("/service-worker")
//   })
// }
