module AI
  class WorkspaceRunnerConnection
    class Error < StandardError; end

    REQUEST_TIMEOUT = 8_000

    def initialize(chat, agent)
      @chat = chat
      @agent = agent
    end

    def open
      if @chat.user&.admin?
        server = @agent&.mcp_servers&.workspace_runner&.active&.find_by(transport_type: %w[streamable_http streamable])
      end
      raise Error, "The local workspace runner is disconnected." unless server

      client = RubyLLM::MCP::Client.new(**server.to_mcp_config, start: false, request_timeout: REQUEST_TIMEOUT)
      client.start
      yield client
    rescue RubyLLM::MCP::Errors::BaseError, ArgumentError => error
      Rails.logger.warn("Workspace runner connection failed: #{error.class}")
      raise Error, connection_error_message(error)
    ensure
      stop(client)
    end

    private

    def connection_error_message(error)
      case error
      when RubyLLM::MCP::Errors::AuthenticationRequiredError
        return "The local workspace runner rejected access. Check the configured runner credentials."
      when RubyLLM::MCP::Errors::TransportError
        if [401, 403].include?(error.code)
          return "The local workspace runner rejected access. Check the connector's credentials and access settings."
        end
      when RubyLLM::MCP::Errors::TimeoutError
        return "The local workspace runner did not respond in time."
      end

      "The local workspace runner could not be reached."
    end

    def stop(client)
      client&.stop
    rescue StandardError => error
      Rails.logger.warn("Workspace runner disconnect failed: #{error.class}")
    end
  end
end
