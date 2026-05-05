# frozen_string_literal: true

module MissionControlEmbeddedUrlOptionsPatch
  private

  def default_url_options
    options = super
    return options unless params[:embedded] == "1"

    options.merge(embedded: "1")
  end
end

Rails.application.config.to_prepare do
  next unless defined?(MissionControl::Jobs::ApplicationController)
  next if MissionControl::Jobs::ApplicationController < MissionControlEmbeddedUrlOptionsPatch

  MissionControl::Jobs::ApplicationController.prepend(MissionControlEmbeddedUrlOptionsPatch)
end
