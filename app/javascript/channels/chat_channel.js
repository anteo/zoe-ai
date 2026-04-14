import consumer from "./consumer"

function createChatSubscription(chatId) {
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
      }
    },

    userTyping: function () {
      this.perform('user_typing')
    }
  });
}

export {createChatSubscription}