// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"
import TC from "@rolemodel/turbo-confirm"
import "./channels"

Turbo.StreamActions.close_modal = function () {
  const id = this.getAttribute("id")
  const modal = id ? document.getElementById(id) : document.querySelector("dialog[data-controller~='app-modal']:last-of-type")
  if (!modal) return

  modal.dispatchEvent(new CustomEvent("app-modal:close", {bubbles: true}))
}

TC.start({
  animationDuration: 200
})
