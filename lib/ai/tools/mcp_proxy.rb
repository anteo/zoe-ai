module AI
  module Tools
    class MCPProxy < Tool
      attr_reader :mcp_tool

      def initialize(chat, mcp_tool)
        super(chat)
        @mcp_tool = mcp_tool
      end

      def name
        mcp_tool.name
      end

      def description
        mcp_tool.description
      end

      def params_schema
        mcp_tool.params_schema
      end

      def progress_payload(**params)
        text = %(Running "#{tool_label}" MCP)
        formatted_params = format_params(params)
        text = "#{text} with #{formatted_params}" if formatted_params.present?

        {
          text:,
          icon: "icon-[lucide--plug-zap]"
        }
      end

      def execute(**params)
        mcp_tool.execute(**params)
      end

      private

      def tool_label
        mcp_tool.respond_to?(:display_name) ? mcp_tool.display_name : mcp_tool.name
      end

      def format_params(params)
        params.map do |key, value|
          "#{key}=#{format_value(value)}"
        end.join(", ").truncate(160)
      end

      def format_value(value)
        case value
        when String
          value
        when Numeric, TrueClass, FalseClass, NilClass
          value.inspect
        else
          value.to_json
        end
      rescue StandardError
        value.inspect
      end
    end
  end
end
