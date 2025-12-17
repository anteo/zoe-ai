module Reline
  class HidingLineEditor < LineEditor
    def hide
      render_differential [], 0, 0
    end

    private def handle_interrupted
      return unless @interrupted

      @interrupted = false
      clear_dialogs
      hide
      cursor_to_bottom_offset = @rendered_screen.lines.size - @rendered_screen.cursor_y
      Reline::IOGate.scroll_down cursor_to_bottom_offset
      Reline::IOGate.move_cursor_column 0
      clear_rendered_screen_cache
      case @old_trap
      when 'DEFAULT', 'SYSTEM_DEFAULT'
        raise Interrupt
      when 'IGNORE'
        # Do nothing
      when 'EXIT'
        exit
      else
        @old_trap.call if @old_trap.respond_to?(:call)
      end
    end
  end
end