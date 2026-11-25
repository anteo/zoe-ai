// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"
import TC from "@rolemodel/turbo-confirm"
import "./channels"

Turbo.StreamActions.reload_agent_runs = function () {
  for (const frame of this.targetElements) {
    if (frame.src) frame.reload()
    else frame.src = frame.dataset.agentRunsUrl
  }
  const conversationId = this.dataset.agentConversationId
  const dialog = document.querySelector('[data-agents="detail"] #agent-conversation-detail[src]')
  if (conversationId && dialog?.dataset.agentConversationId === conversationId) {
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
