module JobRequestStoreContext
  extend ActiveSupport::Concern

  included do
    around_perform :with_request_store
  end

  private

  def with_request_store
    return yield unless defined?(RequestStore)

    RequestStore.begin!
    yield
  ensure
    RequestStore.end!
    RequestStore.clear!
  end
end
