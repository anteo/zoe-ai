require "test_helper"

class WorkspaceRunnerTransportTest < ActiveSupport::TestCase
  test "uses the MCP endpoint origin without its path or query" do
    transport = RubyLLM::MCP::Native::Transports::StreamableHTTP.new(
      url: "http://127.0.0.1:7331/mcp?client=zoe",
      coordinator: nil,
      request_timeout: 8_000,
      headers: { "Authorization" => "Bearer test-token" }
    )

    headers = transport.send(:build_common_headers)
    assert_equal "http://127.0.0.1:7331", headers.fetch("Origin")
    assert_equal "Bearer test-token", headers.fetch("Authorization")
  end
end
