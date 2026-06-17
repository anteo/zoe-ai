import consumer from "./consumer"

function createChatSubscription(chatId, callbacks = {}) {
  return consumer.subscriptions.create({
    channel: "ChatChannel",
    chat_id: chatId
  }, {
    connected() {
      // Called when the subscription is ready for use on the server
    },

    disconnected() {
      // Called when the subscription has been terminated by the server
    },

    received(data) {
      if (data.type === "closed") {
        window.location.href = "/"
      } else if (data.type === "memorize_updated" && callbacks.onMemorizeUpdated) {
        callbacks.onMemorizeUpdated(Boolean(data.memorize))
      } else if (data.type === "tts_audio" && callbacks.onTtsAudio) {
        callbacks.onTtsAudio(data)
      } else if (data.type === "tts_stop" && callbacks.onTtsStop) {
        callbacks.onTtsStop()
      }
    },

    userTyping: function () {
      this.perform('user_typing')
    },

    updateMemorize: function (memorize) {
      this.perform('update_memorize', {memorize})
    },

    stopTts: function () {
      this.perform('stop_tts')
    }
  });
}

export {createChatSubscription}
