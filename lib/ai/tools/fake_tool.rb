module AI
  module Tools
    class FakeTool < Tool
      description "Development-only test tool for the tool progress UI. Use it only when explicitly asked to test tool progress."

      params do
        string :instructions,
               description: "Text to display in the transient tool progress line while the fake tool is running.",
               required: false
      end

      def progress_payload(instructions: nil, **)
        {
          text: instructions.presence || "Testing tool progress",
          icon: "icon-[lucide--flask-conical]"
        }
      end

      def execute(instructions: nil)
        sleep 5
        instructions.presence || "Fake tool completed."
      end
    end
  end
end
