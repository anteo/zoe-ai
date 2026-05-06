# frozen_string_literal: true

module Patches
  module MissionControl
    module Jobs
      module ApplicationControllerPatch
        extend ActiveSupport::Concern

        private

        def default_url_options
          options = super
          return options unless params[:embedded] == "1"

          options.merge(embedded: "1")
        end
      end
    end
  end
end
