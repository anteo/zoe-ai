require "test_helper"

class Settings::MCPServersDatatablesControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

  setup do
    @user = users(:anton)
    @user.update!(admin: true)
    sign_in @user
  end

  test "renders the mcp servers datatable frame" do
    create_mcp_server(name: "Alpha Server", key: "alpha")

    get settings_mcp_servers_datatable_path

    assert_response :success
    assert_includes response.body, %(turbo-frame id="#{datatable_frame_id}")
    assert_includes response.body, %(turbo-frame id="#{datatable_results_frame_id}")
    assert_includes response.body, "Alpha Server"
  end

  test "filters mcp servers with ransack" do
    create_mcp_server(name: "Alpha Search", key: "alpha-search")
    create_mcp_server(name: "Beta Search", key: "beta-search")

    get settings_mcp_servers_datatable_path, params: { q: { name_or_key_or_last_error_cont: "beta" } }

    assert_response :success
    assert_includes response.body, "Beta Search"
    assert_not_includes response.body, "Alpha Search"
  end

  test "sorts mcp servers with ransack" do
    create_mcp_server(name: "Zeta Sort", key: "zeta-sort")
    create_mcp_server(name: "Alpha Sort", key: "alpha-sort")

    get settings_mcp_servers_datatable_path, params: { q: { s: "name desc" } }

    assert_response :success
    assert_operator response.body.index("Zeta Sort"), :<, response.body.index("Alpha Sort")
  end

  test "paginates mcp servers with pagy" do
    12.times do |index|
      create_mcp_server(name: format("Server %02d", index), key: format("server-%02d", index))
    end

    get settings_mcp_servers_datatable_path, params: { page: 2 }

    assert_response :success
    assert_includes response.body, "Server 10"
    assert_not_includes response.body, "Server 00"
  end

  test "settings section keeps the datatable in a nested turbo frame" do
    get settings_path(section: "mcp_servers"), headers: { "Turbo-Frame" => "settings-body" }

    assert_response :success
    assert_includes response.body, 'turbo-frame id="settings__mcp_servers"'
    assert_includes response.body, %(turbo-frame id="#{datatable_frame_id}")
    assert_includes response.body, %(turbo-frame id="#{datatable_results_frame_id}")
    assert_includes response.body, settings_mcp_servers_datatable_path
  end

  private

  def datatable_frame_id
    Settings::MCPServersDatatableComponent.frame_id
  end

  def datatable_results_frame_id
    Settings::MCPServersDatatableComponent.results_frame_id
  end

  def create_mcp_server(name:, key:, **attrs)
    MCPServer.create!(
      {
        active: false,
        config: {},
        key:,
        name:,
        transport_type: "stdio"
      }.merge(attrs)
    )
  end
end
