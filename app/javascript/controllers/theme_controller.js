import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.updateTheme()
    this.mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
    this.mediaQuery.addEventListener('change', this.updateTheme.bind(this))
  }

  disconnect() {
    if (this.mediaQuery) {
      this.mediaQuery.removeEventListener('change', this.updateTheme.bind(this))
    }
  }

  updateTheme() {
    const isDark = window.matchMedia('(prefers-color-scheme: dark)').matches
    const theme = isDark ? 'dark' : 'light'
    document.documentElement.setAttribute('data-theme', theme)
  }
}