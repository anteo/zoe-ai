module AI::Actors
  class DescribeMessageAttachments < Actor
    input :chat, type: Chat
    input :logger, default: -> { Rails.logger }

    fail_on RubyLLM::Error

    def call
      return unless vision_enabled_for_attachment_description?

      messages_to_process.find_each do |message|
        message.attachments.select(&:image?).each do |attachment|
          next if attachment.description.present?
          next if attachment.metadata["prompt"].present?

          describe_attachment!(attachment, message)
        end
      end
    end

    private

    def messages_to_process
      chat.messages
          .visible
          .where(role: "user")
          .preload(attachments_attachments: :blob)
    end

    def describe_attachment!(attachment, message)
      response = describe_attachment_chat.ask(RubyLLM::Content.new(nil, [ attachment ]))

      description = response.content.to_s.squish
      return if description.blank?

      attachment.description = description
      attachment.blob.save! if attachment.blob.changed?
      logger.debug "<<< attachment ##{attachment.blob.id} described for message ##{message.id}: #{description}"
    end

    def describe_attachment_chat
      @describe_attachment_chat ||= AI::Agents::DescribeAttachment.chat(chat:)
    end

    def vision_enabled_for_attachment_description?
      describe_attachment_chat.model.respond_to?(:supports_vision?) && describe_attachment_chat.model.supports_vision?
    end
  end
end
