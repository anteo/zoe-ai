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
    this.boundHandleSystemThemeChange = this.handleSystemThemeChange.bind(this)

    this.applyTheme()
    this.syncControls()
    this.mediaQuery.addEventListener("change", this.boundHandleSystemThemeChange)
  }

  disconnect() {
    if (this.mediaQuery) {
      this.mediaQuery.removeEventListener("change", this.boundHandleSystemThemeChange)
    }
  }

  toggle(event) {
    const mode = event.target.checked ? "dark" : "light"
    this.setMode(mode)
    this.applyTheme()
    this.syncControls()
  }

  selectTheme(event) {
    const themeId = event.target.value
    const mode = this.currentMode()

    if (!this.validThemeForMode(themeId, mode)) return

    this.setThemeIdForMode(mode, themeId)
    this.applyTheme()
    this.syncControls()
  }

  handleSystemThemeChange() {
    localStorage.removeItem(this.modeStorageKey)
    this.applyTheme()
    this.syncControls()
  }

  applyTheme() {
    const mode = this.currentMode()
    const themeId = this.themeIdForMode(mode)

    document.documentElement.setAttribute("data-theme", themeId)
    document.documentElement.setAttribute("data-theme-mode", mode)
  }

  syncControls() {
    const mode = this.currentMode()
    const isDark = mode === "dark"

    document.querySelectorAll(".theme-mode-controller").forEach((switcher) => {
      switcher.checked = isDark
    })

    const select = document.querySelector("[data-theme-select]")
    if (!select) return

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

  setMode(mode) {
    localStorage.setItem(this.modeStorageKey, mode)
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
    const optionMarkup = themes.map((themeId) => `<option value="${themeId}">${themeId}</option>`).join("")

    if (select.dataset.themeMode === mode && select.options.length === themes.length) return

    select.innerHTML = optionMarkup
    select.dataset.themeMode = mode
  }
}
