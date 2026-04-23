// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"
import TC from "@rolemodel/turbo-confirm"
import "./channels"
import { closeAppModal, installAppModal } from "./lib/app_modal"

installAppModal()

Turbo.StreamActions.redirect = function () {
  const url = this.getAttribute("url") || window.location.href
  const visit = () => Turbo.visit(url, {action: "replace"})

  closeAppModal().then(visit)
}

TC.start({
  animationDuration: 200
})
