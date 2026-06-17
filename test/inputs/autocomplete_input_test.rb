require "test_helper"

class AutocompleteInputTest < ActiveSupport::TestCase
  test "settings autocomplete fields render translated placeholders" do
    html = ApplicationController.render(
      inline: <<~ERB,
        <%= simple_form_for Setting.ai.models, url: "/", builder: SettingsFormBuilder do |f| %>
          <%= f.input :default_embedding_model, as: :autocomplete, url: "/models" %>
          <%= f.input :default_tts_model, as: :autocomplete, url: "/models" %>
        <% end %>
      ERB
    )

    assert_includes html, 'name="models[default_embedding_model_autocomplete]"'
    assert_includes html, 'name="models[default_tts_model_autocomplete]"'
    assert_equal 2, html.scan('placeholder="Choose model..."').size
  end
end
