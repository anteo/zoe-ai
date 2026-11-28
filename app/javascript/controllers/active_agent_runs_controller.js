import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "card", "strip", "single", "name", "status", "menu", "count", "items", "itemTemplate"]

  initialize() {
    this.resizeObserver = new ResizeObserver(this.queueUpdate)
  }

  connect() {
    this.queueUpdate()
  }

  disconnect() {
    this.resizeObserver.disconnect()
    cancelAnimationFrame(this.updateFrame)
    this.updateFrame = null
    this.renderedCards = null
  }

  messagesTargetConnected(messages) {
    this.resizeObserver.observe(messages)
    this.queueUpdate()
  }

  messagesTargetDisconnected(messages) {
    this.resizeObserver.unobserve(messages)
  }

  stripTargetConnected() {
    this.renderedCards = null
    this.queueUpdate()
  }

  cardTargetConnected() {
    this.queueUpdate()
  }

  cardTargetDisconnected() {
    this.queueUpdate()
  }

  queueUpdate = () => {
    if (this.updateFrame != null) return

    this.updateFrame = requestAnimationFrame(() => {
      this.updateFrame = null
      this.updateStrip()
    })
  }

  updateStrip() {
    if (!this.hasMessagesTarget || !this.hasStripTarget) return

    const viewport = this.messagesTarget.getBoundingClientRect()
    const cards = this.cardTargets.filter((card) => {
      const { top, bottom, height } = card.getBoundingClientRect()
      return height > 0 && (bottom <= viewport.top || top >= viewport.bottom)
    })
    const signature = JSON.stringify(cards.map((card) => [
      card.parentElement.id,
      card.dataset.agentRunName,
      card.dataset.agentRunTask,
      cards.length === 1 ? card.dataset.agentRunStatus : null,
      this.dialogLink(card)?.href
    ]))
    if (signature === this.renderedCards) return

    this.renderedCards = signature
    this.stripTarget.inert = cards.length === 0
    if (cards.length < 2) this.menuTarget.open = false
    if (cards.length === 0) return

    this.singleTarget.hidden = cards.length !== 1
    this.menuTarget.hidden = cards.length < 2
    if (cards.length === 1) {
      const [card] = cards
      this.nameTarget.textContent = card.dataset.agentRunName
      this.statusTarget.textContent = card.dataset.agentRunStatus
      this.setLink(this.singleTarget, card)
    } else {
      this.countTarget.textContent = cards.length
      this.itemsTarget.replaceChildren(...cards.map((card) => this.menuItem(card)))
    }
  }

  menuItem(card) {
    const item = this.itemTemplateTarget.content.cloneNode(true)
    item.querySelector("[data-agent-run-item-name]").textContent = card.dataset.agentRunName
    item.querySelector("[data-agent-run-item-task]").textContent = card.dataset.agentRunTask
    this.setLink(item.querySelector("a"), card)
    return item
  }

  dialogLink(card) {
    return card.querySelector("[data-agent-conversation-id]")
  }

  setLink(link, card) {
    const dialog = this.dialogLink(card)
    if (dialog) {
      link.href = dialog.href
      link.dataset.action = dialog.dataset.action
      link.dataset.agentConversationId = dialog.dataset.agentConversationId
      link.dataset.turboFrame = dialog.dataset.turboFrame
      link.dataset.turboPrefetch = "false"
      delete link.dataset.agentRunCardId
    } else {
      link.href = `#${card.parentElement.id}`
      link.dataset.action = "click->active-agent-runs#showCard"
      link.dataset.agentRunCardId = card.parentElement.id
      delete link.dataset.agentConversationId
      delete link.dataset.turboFrame
    }
  }

  showCard(event) {
    event.preventDefault()
    const card = this.cardTargets.find((item) => item.parentElement.id === event.currentTarget.dataset.agentRunCardId)
    if (!card) return

    card.focus({ preventScroll: true })
    const behavior = window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "instant" : "smooth"
    card.scrollIntoView({ block: "nearest", behavior })
  }

  closeMenu(event) {
    if (!this.menuTarget.open) return

    event.preventDefault()
    this.menuTarget.open = false
    this.menuTarget.querySelector("summary").focus()
  }
}
