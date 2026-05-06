import consumer from "./consumer"

function createAdminConsoleSubscription(level, callbacks = {}) {
  return consumer.subscriptions.create({
    channel: "AdminConsoleChannel",
    level
  }, {
    received(data) {
      switch (data?.type) {
        case "snapshot":
          callbacks.onSnapshot?.(data)
          break
        case "append":
          callbacks.onAppend?.(data.log)
          break
        default:
          callbacks.onMessage?.(data)
          break
      }
    }
  })
}

export {createAdminConsoleSubscription}
