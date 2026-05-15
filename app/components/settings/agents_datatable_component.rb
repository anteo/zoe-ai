module Settings
  class AgentsDatatableComponent < Datatable::BaseComponent
    model Agent
    default_sort "name asc"
    empty_state_i18n_key :text_no_agents
    path_helper :agents_path
  end
end
