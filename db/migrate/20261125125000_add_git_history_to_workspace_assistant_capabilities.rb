class AddGitHistoryToWorkspaceAssistantCapabilities < ActiveRecord::Migration[8.1]
  OLD_DESCRIPTION = "Lists and searches local projects, reads, creates, edits, moves and deletes files, creates directories, and runs shell commands and tests in an isolated project environment."
  NEW_DESCRIPTION = "Lists and searches local projects, reads, creates, edits, moves and deletes files, creates directories, reads Git commit history from the original repositories, and runs shell commands and tests in an isolated project environment."

  def up
    update_description(OLD_DESCRIPTION, NEW_DESCRIPTION)
  end

  def down
    update_description(NEW_DESCRIPTION, OLD_DESCRIPTION)
  end

  private

  def update_description(previous, current)
    execute <<~SQL
      UPDATE agents
      SET description = #{connection.quote(current)}
      WHERE key = 'workspace_assistant' AND description = #{connection.quote(previous)}
    SQL
  end
end
