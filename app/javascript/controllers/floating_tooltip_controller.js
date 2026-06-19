import {Controller} from "@hotwired/stimulus"
import {autoUpdate, computePosition, flip, offset, shift} from "@floating-ui/dom"

const PLACEMENT_CLASSES = {
  top: "tooltip-top",
  bottom: "tooltip-bottom",
  left: "tooltip-left",
  right: "tooltip-right"
}

const VARIANT_CLASSES = {
  accent: "tooltip-accent",
  error: "tooltip-error",
  info: "tooltip-info",
  neutral: "tooltip-neutral",
  primary: "tooltip-primary",
  secondary: "tooltip-secondary",
  success: "tooltip-success",
  warning: "tooltip-warning"
}

export default class extends Controller {
  static targets = ["anchor"]
  static values = {
    content: String,
    offset: {type: Number, default: 8},
    placement: {type: String, default: "top"},
    variant: {type: String, default: "neutral"}
  }

  connect() {
    this.handleMouseEnter = this.handleMouseEnter.bind(this)
    this.handleMouseLeave = this.handleMouseLeave.bind(this)
    this.handleHideEvent = this.handleHideEvent.bind(this)
    this.handleShowEvent = this.handleShowEvent.bind(this)
    this.handleUpdateEvent = this.handleUpdateEvent.bind(this)

    this.hovered = false
    this.pinnedOpen = false

    this.buildFloatingElement()
    this.registerListeners()
    this.render()
  }

  update(event) {
    this.applyDetail(event.detail)
    this.render()
  }

  show(event) {
    this.applyDetail(event.detail)
    this.pinnedOpen = true
    this.render()
  }

  hide() {
    this.pinnedOpen = false
    this.render()
  }

  handleUpdateEvent(event) {
    this.update(event)
  }

  handleShowEvent(event) {
    this.show(event)
  }

  handleHideEvent() {
    this.hide()
  }

  contentValueChanged() {
    this.render()
  }

  variantValueChanged() {
    this.render()
  }

  registerListeners() {
    const anchor = this.anchorElement()
    this.element.addEventListener("floating-tooltip:update", this.handleUpdateEvent)
    this.element.addEventListener("floating-tooltip:show", this.handleShowEvent)
    this.element.addEventListener("floating-tooltip:hide", this.handleHideEvent)
    if (!anchor) return

    anchor.addEventListener("mouseenter", this.handleMouseEnter)
    anchor.addEventListener("mouseleave", this.handleMouseLeave)
  }

  unregisterListeners() {
    const anchor = this.anchorElement()
    this.element.removeEventListener("floating-tooltip:update", this.handleUpdateEvent)
    this.element.removeEventListener("floating-tooltip:show", this.handleShowEvent)
    this.element.removeEventListener("floating-tooltip:hide", this.handleHideEvent)
    if (!anchor) return

    anchor.removeEventListener("mouseenter", this.handleMouseEnter)
    anchor.removeEventListener("mouseleave", this.handleMouseLeave)
  }

  handleMouseEnter() {
    this.hovered = true
    this.render()
  }

  handleMouseLeave() {
    this.hovered = false
    this.render()
  }

  buildFloatingElement() {
    if (this.tooltipElement) return

    this.tooltipElement = document.createElement("div")
    this.tooltipElement.className = "floating-tooltip tooltip tooltip-top pointer-events-none fixed left-0 top-0 z-50 h-0 w-0"
    this.tooltipElement.setAttribute("data-tip", "")

    this.measureElement = document.createElement("div")
    this.measureElement.className = "pointer-events-none fixed left-0 top-0 invisible w-max max-w-xs rounded-field px-2 py-1 text-center text-sm leading-tight whitespace-normal break-words shadow-lg"

    document.body.appendChild(this.tooltipElement)
    document.body.appendChild(this.measureElement)
  }

  render() {
    if (!this.tooltipElement || !this.measureElement) return

    const content = this.contentValue || ""
    const shouldOpen = (this.hovered || this.pinnedOpen) && content.length > 0

    this.tooltipElement.dataset.tip = content
    this.measureElement.textContent = content

    if (!shouldOpen) {
      this.tooltipElement.classList.remove("tooltip-open")
      this.cleanupAutoUpdate()
      return
    }

    this.applyVariantClass()
    this.updatePosition()
  }

  updatePosition() {
    const anchor = this.anchorElement()
    if (!anchor || !this.tooltipElement || !this.measureElement) return

    this.cleanupAutoUpdate()
    this.cleanupPosition = autoUpdate(anchor, this.tooltipElement, () => {
      computePosition(anchor, this.measureElement, {
        placement: this.currentPlacement(),
        middleware: [
          offset(this.offsetValue),
          flip(),
          shift({padding: 8})
        ]
      }).then(({x, y, placement}) => {
        const width = this.measureElement.offsetWidth
        const height = this.measureElement.offsetHeight
        const side = placement.split("-")[0]
        const anchorRect = anchor.getBoundingClientRect()

        this.applyPlacementClass(side)

        const gap = this.offsetValue
        const point = {
          left: x + width / 2,
          top: y + height + gap
        }

        if (side === "bottom") {
          point.top = y - gap
        } else if (side === "left") {
          point.left = x + width + gap
          point.top = y + height / 2
        } else if (side === "right") {
          point.left = x - gap
          point.top = y + height / 2
        }

        this.tooltipElement.style.left = `${point.left}px`
        this.tooltipElement.style.top = `${point.top}px`
        this.tooltipElement.style.setProperty(
          "--ft-anchor-dx",
          `${this.clamp(anchorRect.left + anchorRect.width / 2 - (x + width / 2), 12 - width / 2, width / 2 - 12)}px`
        )
        this.tooltipElement.style.setProperty(
          "--ft-anchor-dy",
          `${this.clamp(anchorRect.top + anchorRect.height / 2 - (y + height / 2), 8 - height / 2, height / 2 - 8)}px`
        )
        this.tooltipElement.style.setProperty("--tt-off", `${gap}px`)
        this.tooltipElement.style.setProperty("--tt-tail", `calc(${gap}px - 0.25rem + 1px)`)

        this.tooltipElement.classList.add("tooltip-open")
      })
    })
  }

  cleanupAutoUpdate() {
    if (this.cleanupPosition) {
      this.cleanupPosition()
      this.cleanupPosition = null
    }
  }

  applyDetail(detail = {}) {
    if (Object.prototype.hasOwnProperty.call(detail, "text")) {
      this.contentValue = detail.text || ""
    }

    if (Object.prototype.hasOwnProperty.call(detail, "variant")) {
      this.variantValue = this.normalizeVariant(detail.variant)
    }
  }

  applyVariantClass() {
    Object.values(VARIANT_CLASSES).forEach((className) => {
      this.tooltipElement.classList.remove(className)
    })

    const variant = this.currentVariant()
    this.tooltipElement.classList.add(VARIANT_CLASSES[variant])
  }

  applyPlacementClass(side) {
    Object.values(PLACEMENT_CLASSES).forEach((className) => {
      this.tooltipElement.classList.remove(className)
    })

    this.tooltipElement.classList.add(PLACEMENT_CLASSES[side] || PLACEMENT_CLASSES.top)
  }

  normalizeVariant(value) {
    return ["accent", "error", "info", "neutral", "primary", "secondary", "success", "warning"].includes(value)
      ? value
      : "neutral"
  }

  currentPlacement() {
    const anchorPlacement = this.anchorElement()?.dataset.floatingTooltipPlacementValue
    const value = anchorPlacement || this.placementValue
    return ["top", "bottom", "left", "right"].includes(value) ? value : "top"
  }

  currentVariant() {
    const anchorVariant = this.anchorElement()?.dataset.floatingTooltipVariantValue
    return this.normalizeVariant(anchorVariant || this.variantValue)
  }

  clamp(value, min, max) {
    return Math.min(Math.max(value, min), max)
  }

  disconnect() {
    this.unregisterListeners()
    this.cleanupAutoUpdate()
    this.tooltipElement?.remove()
    this.measureElement?.remove()
    this.tooltipElement = null
    this.measureElement = null
  }

  anchorElement() {
    return this.hasAnchorTarget ? this.anchorTarget : this.element.firstElementChild
  }
}
