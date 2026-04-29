import consumer from "./consumer"

function createAdminConsoleSubscription(callbacks = {}) {
  return consumer.subscriptions.create({
    channel: "AdminConsoleChannel"
  }, {
    received(data) {
      callbacks.onMessage?.(data)
    }
  })
}

export {createAdminConsoleSubscription}
