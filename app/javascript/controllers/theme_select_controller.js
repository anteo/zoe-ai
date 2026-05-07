import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static LIGHT_THEMES = [
    "acid",
    "autumn",
    "bumblebee",
    "caramellatte",
    "cmyk",
    "corporate",
    "cupcake",
    "cyberpunk",
    "emerald",
    "fantasy",
    "garden",
    "lemonade",
    "light",
    "lofi",
    "nord",
    "pastel",
    "retro",
    "silk",
    "valentine",
    "winter",
    "wireframe"
  ]
  static DARK_THEMES = [
    "abyss",
    "aqua",
    "black",
    "business",
    "coffee",
    "dark",
    "dim",
    "dracula",
    "forest",
    "halloween",
    "luxury",
    "night",
    "sunset",
    "synthwave"
  ]
  static DEFAULT_LIGHT_THEME = "light"
  static DEFAULT_DARK_THEME = "dark"

  connect() {
    this.modeStorageKey = "theme-mode"
    this.lightThemeStorageKey = "theme-light-id"
    this.darkThemeStorageKey = "theme-dark-id"
    this.mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
    this.boundSync = this.sync.bind(this)

    this.sync()
    document.addEventListener("theme:changed", this.boundSync)
    document.addEventListener("turbo:render", this.boundSync)
    document.addEventListener("turbo:after-stream-render", this.boundSync)
  }

  disconnect() {
    document.removeEventListener("theme:changed", this.boundSync)
    document.removeEventListener("turbo:render", this.boundSync)
    document.removeEventListener("turbo:after-stream-render", this.boundSync)
  }

  selectTheme(event) {
    const themeId = event.target.value
    const mode = this.currentMode()

    if (!this.validThemeForMode(themeId, mode)) return

    this.setThemeIdForMode(mode, themeId)
    this.applyTheme(mode)
    this.sync()
  }

  sync() {
    const mode = this.currentMode()
    const select = this.element

    this.renderThemeOptions(select, mode)
    select.value = this.themeIdForMode(mode)
  }

  systemTheme() {
    return this.mediaQuery.matches ? "dark" : "light"
  }

  currentMode() {
    const savedMode = localStorage.getItem(this.modeStorageKey)
    return savedMode || this.systemTheme()
  }

  themeIdForMode(mode) {
    const key = mode === "dark" ? this.darkThemeStorageKey : this.lightThemeStorageKey
    const savedThemeId = localStorage.getItem(key)
    const defaultThemeId = mode === "dark" ? this.constructor.DEFAULT_DARK_THEME : this.constructor.DEFAULT_LIGHT_THEME

    if (this.validThemeForMode(savedThemeId, mode)) {
      return savedThemeId
    }

    return defaultThemeId
  }

  setThemeIdForMode(mode, themeId) {
    const key = mode === "dark" ? this.darkThemeStorageKey : this.lightThemeStorageKey
    localStorage.setItem(key, themeId)
  }

  validThemeForMode(themeId, mode) {
    if (!themeId) return false

    const themes = mode === "dark" ? this.constructor.DARK_THEMES : this.constructor.LIGHT_THEMES
    return themes.includes(themeId)
  }

  renderThemeOptions(select, mode) {
    const themes = mode === "dark" ? this.constructor.DARK_THEMES : this.constructor.LIGHT_THEMES
    const optionMarkup = themes.map((id) => `<option value="${id}">${id}</option>`).join("")

    if (select.dataset.themeMode === mode && select.options.length === themes.length) return

    select.innerHTML = optionMarkup
    select.dataset.themeMode = mode
  }

  applyTheme(mode) {
    const themeId = this.themeIdForMode(mode)

    document.documentElement.setAttribute("data-theme", themeId)
    document.documentElement.setAttribute("data-theme-mode", mode)
    document.dispatchEvent(new CustomEvent("theme:changed", { detail: { mode, themeId } }))
  }
}
