import { Controller } from "@hotwired/stimulus"
import { EditorState } from "@codemirror/state"
import { EditorView } from "@codemirror/view"
import { basicSetup } from "codemirror"
import { json } from "@codemirror/lang-json"

export default class extends Controller {
  static values = {
    language: String,
    readOnly: Boolean
  }

  connect() {
    if (!(this.element instanceof HTMLTextAreaElement) || this.view) return

    this.wrapper = document.createElement("div")
    this.wrapper.className = "textarea w-full p-0 overflow-hidden"
    this.element.insertAdjacentElement("beforebegin", this.wrapper)
    this.element.classList.add("hidden")

    this.view = new EditorView({
      state: EditorState.create({
        doc: this.element.value,
        extensions: [
          basicSetup,
          ...this.languageExtensions(),
          EditorView.lineWrapping,
          EditorState.readOnly.of(this.readOnlyValue || this.element.readOnly || this.element.disabled),
          EditorView.updateListener.of((update) => {
            if (!update.docChanged) return

            this.syncTextarea(update.state.doc.toString())
          })
        ]
      }),
      parent: this.wrapper
    })

    if (this.element.autofocus) {
      this.view.focus()
    }
  }

  disconnect() {
    this.view?.destroy()
    this.view = null
    this.wrapper?.remove()
    this.wrapper = null
    this.element.classList.remove("hidden")
  }

  syncTextarea(value) {
    this.element.value = value
    this.element.dispatchEvent(new Event("input", { bubbles: true }))
    this.element.dispatchEvent(new Event("change", { bubbles: true }))
  }

  languageExtensions() {
    switch (this.languageValue) {
      case "json":
        return [json()]
      default:
        return []
    }
  }
}
