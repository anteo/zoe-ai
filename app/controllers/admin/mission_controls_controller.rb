# frozen_string_literal: true

module Admin
  class MissionControlsController < ApplicationController
    before_action :require_admin!

    def show
      render_modal
    end
  end
end
