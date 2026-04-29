class AdminConsoleChannel < ApplicationCable::Channel
  STREAM = "admin_console".freeze

  def subscribed
    reject unless current_user&.admin?
    stream_from STREAM
  end
end
