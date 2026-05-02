class AutocompleteInput < SimpleForm::Inputs::Base
  def input(wrapper_options = nil)
    input_html_options[:autocomplete] = "off"
    input_html_options[:data] ||= {}
    input_html_options[:data][:autocomplete_target] = "input"
    input_html_options[:value] ||= @builder.object.public_send(attribute_name)

    opts = wrapper_options || {}

    template.tag.div(
      role: "combobox",
      class: opts[:autocomplete_container_class],
      data: autocomplete_data,
    ) do
      template.safe_join(
        [
          @builder.text_field(
            :"#{attribute_name}_autocomplete",
            merge_wrapper_options(input_html_options, wrapper_options)
          ),

          @builder.hidden_field(
            attribute_name,
            data: {
              autocomplete_target: "hidden"
            }
          ),

          template.tag.ul(
            "",
            class: opts[:autocomplete_results_class],
            hidden: true,
            data: { autocomplete_target: "results" }
          )
        ]
      )
    end
  end

  private

  def autocomplete_data
    {
      controller: "autocomplete",
      autocomplete_url_value: options.fetch(:url),
      autocomplete_query_param_value: options[:query_param],
      autocomplete_min_length_value: options[:min_length],
      autocomplete_delay_value: options[:delay],
    }.compact
  end
end
