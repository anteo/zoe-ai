module Ai
  module RackAttack
    module_function

    def public_login?(request)
      request.post? && request.path == "/login"
    end

    def public_registration?(request)
      request.post? && request.path == "/register"
    end

    def oauth_flow?(request)
      return true if request.post? && request.path == "/auth/google_oauth2"

      request.path == "/auth/google_oauth2/callback" && (request.get? || request.post?)
    end

    def password_recovery_mail?(request)
      request.post? && request.path == "/password"
    end

    def confirmation_mail?(request)
      request.post? && request.path == "/confirmation"
    end

    def recovery_token?(request)
      (request.get? && request.path.in?([ "/confirmation", "/password/edit" ])) ||
        ((request.patch? || request.put?) && request.path == "/password")
    end

    def authenticated_chat_generation?(request)
      return true if request.post? && request.path == "/messages"

      return true if request.path.match?(%r{\A/messages/\d+/resend\z}) && request.post?

      request.path.match?(%r{\A/messages/\d+\z}) && (request.patch? || request.put?)
    end

    def direct_upload?(request)
      request.post? && request.path == "/rails/active_storage/direct_uploads"
    end

    def share_mail?(request)
      request.post? && request.path.match?(%r{\A/characters/\d+/deliver_share\z})
    end

    def authenticated_write?(request)
      return true if request.post? && request.path == "/characters"

      return true if request.path.match?(%r{\A/characters/\d+\z}) && (request.patch? || request.put?)

      request.path == "/profile" && (request.patch? || request.put?)
    end

    def admin_search?(request)
      request.get? && request.path == "/models/search"
    end

    def admin_write?(request)
      return true if request.path.in?([ "/agents", "/mcp_servers" ]) && request.post?
      return true if request.path == "/settings" && (request.patch? || request.put?)
      return true if request.path.start_with?("/admin/mission_control/app") && !request.get?

      return true if request.path.match?(%r{\A/agents/\d+\z}) && !request.get?
      return true if request.path.match?(%r{\A/mcp_servers/\d+\z}) && !request.get?

      request.path.match?(%r{\A/mcp_servers/\d+/(start|stop)\z}) && request.patch?
    end

    def authenticated_key(request)
      user_id = authenticated_user_id(request)
      return "user:#{user_id}" if user_id.present?

      ip_key(request)
    end

    def admin_key(request)
      user_id = authenticated_user_id(request)
      return "admin:#{user_id}" if user_id.present? && User.where(id: user_id, admin: true).exists?

      ip_key(request)
    end

    def authenticated_user_id(request)
      request.env["warden"]&.user(:user)&.id || session_user_id(request)
    end

    def session_user_id(request)
      session = request.session
      key = session["warden.user.user.key"] || session[:'warden.user.user.key']
      Array(key).dig(0, 0)
    rescue StandardError
      nil
    end

    def ip_key(request)
      "ip:#{request.ip}"
    end
  end
end

Rack::Attack.enabled = true
Rack::Attack.cache.store =
  if Rails.cache.is_a?(ActiveSupport::Cache::NullStore)
    ActiveSupport::Cache::MemoryStore.new
  else
    Rails.cache
  end

Rack::Attack.safelist("allow-health-check") do |request|
  request.path == "/up"
end

Rack::Attack.throttled_responder = lambda do |request|
  match_data = request.env["rack.attack.match_data"] || {}
  retry_after = match_data[:period].to_i

  [
    429,
    {
      "Content-Type" => "text/plain; charset=utf-8",
      "Retry-After" => retry_after.to_s
    },
    [ "Too many requests" ]
  ]
end

Rack::Attack.throttle("public/login", limit: 6, period: 1.minute) do |request|
  Ai::RackAttack.ip_key(request) if Ai::RackAttack.public_login?(request)
end

Rack::Attack.throttle("public/registration", limit: 3, period: 10.minutes) do |request|
  Ai::RackAttack.ip_key(request) if Ai::RackAttack.public_registration?(request)
end

Rack::Attack.throttle("public/oauth", limit: 10, period: 5.minutes) do |request|
  Ai::RackAttack.ip_key(request) if Ai::RackAttack.oauth_flow?(request)
end

Rack::Attack.throttle("public/password-recovery-mail", limit: 3, period: 15.minutes) do |request|
  Ai::RackAttack.ip_key(request) if Ai::RackAttack.password_recovery_mail?(request)
end

Rack::Attack.throttle("public/confirmation-mail", limit: 3, period: 15.minutes) do |request|
  Ai::RackAttack.ip_key(request) if Ai::RackAttack.confirmation_mail?(request)
end

Rack::Attack.throttle("public/recovery-token", limit: 10, period: 15.minutes) do |request|
  Ai::RackAttack.ip_key(request) if Ai::RackAttack.recovery_token?(request)
end

Rack::Attack.throttle("authenticated/chat-generation", limit: 20, period: 1.minute) do |request|
  Ai::RackAttack.authenticated_key(request) if Ai::RackAttack.authenticated_chat_generation?(request)
end

Rack::Attack.throttle("authenticated/direct-upload", limit: 20, period: 5.minutes) do |request|
  Ai::RackAttack.authenticated_key(request) if Ai::RackAttack.direct_upload?(request)
end

Rack::Attack.throttle("authenticated/share-mail", limit: 3, period: 1.hour) do |request|
  Ai::RackAttack.authenticated_key(request) if Ai::RackAttack.share_mail?(request)
end

Rack::Attack.throttle("authenticated/write", limit: 15, period: 5.minutes) do |request|
  Ai::RackAttack.authenticated_key(request) if Ai::RackAttack.authenticated_write?(request)
end

Rack::Attack.throttle("admin/search", limit: 50, period: 1.minute) do |request|
  Ai::RackAttack.admin_key(request) if Ai::RackAttack.admin_search?(request)
end

Rack::Attack.throttle("admin/write", limit: 10, period: 5.minutes) do |request|
  Ai::RackAttack.admin_key(request) if Ai::RackAttack.admin_write?(request)
end
