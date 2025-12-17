module AI
  module Tools
    class MCP < Tool
      using Rainbow

      class FunctionSchemas
        def tools
          AI.mcp_client.list_tools
        end

        def to_openai_format
          tools.map do |tool|
            {
              type: "function",
              function: {
                name: "#{MCP.tool_name}__#{tool.name}",
                description: tool.description,
                parameters: tool.schema
              }
            }
          end
        end
      end

      def self.tool_name
        "mcp"
      end

      def self.function_schemas
        @function_schemas ||= FunctionSchemas.new
      end

      def execute_tool_method(tool_name, **kwargs)
        puts "MCP call to #{tool_name}(#{kwargs.inspect})".faint
        result = AI.mcp_client.call_tool(tool_name, kwargs)["content"]
        puts "Output: #{result}".faint
        result
      rescue StandardError => e
        e.message
      end
    end
  end
end
