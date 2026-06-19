require "test_helper"
require "ostruct"

class ChatTranscriptionsControllerTest < ActionDispatch::IntegrationTest
  fixtures :characters, :characters_users, :chats, :users

  test "transcribes uploaded audio for the current chat" do
    authenticate_as(users(:anton))

    transcription = OpenStruct.new(text: "hello from voice")
    audio = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/voice.webm"), "audio/webm")

    RubyLLM.stub(:transcribe, transcription) do
      post voice_transcription_path, params: { audio: }
    end

    assert_response :success
    assert_equal "hello from voice", response.parsed_body["text"]
  end

  private

  def authenticate_as(user, password: "password123")
    post user_session_path, params: { user: { email: user.email, password: } }
    assert_not_equal 429, response.status
  end
end
