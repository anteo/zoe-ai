class UpdateWorkspaceAssistantCapabilities < ActiveRecord::Migration[8.1]
  OLD_DESCRIPTION = "Lists local projects, searches their files, and reads file contents by workspace-relative path."
  NEW_DESCRIPTION = "Lists and searches local projects, reads, creates, edits, moves and deletes files, creates directories, and runs shell commands and tests in an isolated project environment."
  OLD_INSTRUCTION = "Use the local workspace tool to list, search, or read files when it is available, and report its actual outcome."
  NEW_INSTRUCTION = "Use the local workspace tool to carry out the requested work and report its actual outcome."

  def up
    update_defaults(OLD_DESCRIPTION, NEW_DESCRIPTION, OLD_INSTRUCTION, NEW_INSTRUCTION)
  end

  def down
    update_defaults(NEW_DESCRIPTION, OLD_DESCRIPTION, NEW_INSTRUCTION, OLD_INSTRUCTION)
  end

  private

  def update_defaults(old_description, new_description, old_instruction, new_instruction)
    execute <<~SQL
      UPDATE agents SET description = #{connection.quote(new_description)}
      WHERE key = 'workspace_assistant' AND description = #{connection.quote(old_description)}
    SQL
    execute <<~SQL
      UPDATE agents SET instructions = replace(instructions, #{connection.quote(old_instruction)}, #{connection.quote(new_instruction)})
      WHERE key = 'workspace_assistant' AND strpos(instructions, #{connection.quote(old_instruction)}) > 0
    SQL
  end
end
