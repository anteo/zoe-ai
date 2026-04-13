# frozen_string_literal: true

class CharactersController < ApplicationController
  def select
    session[:character_id] = params[:character_id]
    redirect_to root_path
  end
end
