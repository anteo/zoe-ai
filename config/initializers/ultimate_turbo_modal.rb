# frozen_string_literal: true

UltimateTurboModal.configure do |config|
  config.flavor = :daisy_ui
  # config.allowed_click_outside_selector = []

  config.modal do |m|
    m.advance = false
    m.close_button = true
    m.header = true
    m.header_divider = false
    m.footer_divider = false
    m.padding = true
    m.overlay = true
  end

  # config.drawer do |d|
  #   d.position = :right
  #   d.close_button = true
  #   d.header = true
  #   d.header_divider = false
  #   d.footer_divider = true
  #   d.padding = true
  #   d.overlay = true
  #   d.size = :md
  # end
end
