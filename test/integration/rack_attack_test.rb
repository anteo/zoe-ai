require "test_helper"
require "base64"
require "digest/md5"

class RackAttackTest < ActionDispatch::IntegrationTest
  fixtures :characters, :characters_users, :chats, :users

  setup do
    Rack::Attack.cache.store.clear
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    Rack::Attack.cache.store.clear
  end

  test "throttles repeated login attempts by ip" do
    6.times do
      post user_session_path, params: { user: { email: "anton@example.com", password: "wrong-password" } }
      assert_not_equal 429, response.status
    end

    post user_session_path, params: { user: { email: "anton@example.com", password: "wrong-password" } }

    assert_response :too_many_requests
  end

  test "password recovery and confirmation throttles are separate" do
    3.times do
      post user_password_path, params: { user: { email: "anton@example.com" } }
      assert_not_equal 429, response.status
    end

    post user_password_path, params: { user: { email: "anton@example.com" } }
    assert_response :too_many_requests

    3.times do
      post user_confirmation_path, params: { user: { email: "anton@example.com" } }
      assert_not_equal 429, response.status
    end

    post user_confirmation_path, params: { user: { email: "anton@example.com" } }
    assert_response :too_many_requests
  end

  test "throttles repeated authenticated message creation" do
    authenticate_as(users(:anton))

    20.times do |index|
      post messages_path, params: { chat_id: chats(:anton_with_zoe).id, message: { content: "hello #{index}" } }
      assert_not_equal 429, response.status
    end

    post messages_path, params: { chat_id: chats(:anton_with_zoe).id, message: { content: "blocked" } }

    assert_response :too_many_requests
  end

  test "throttles authenticated direct upload bursts" do
    authenticate_as(users(:anton))

    20.times do |index|
      post rails_direct_uploads_path, params: { blob: direct_upload_blob_params(index) }, as: :json
      assert_not_equal 429, response.status
    end

    post rails_direct_uploads_path, params: { blob: direct_upload_blob_params("blocked") }, as: :json

    assert_response :too_many_requests
  end

  test "throttles share mail aggressively" do
    authenticate_as(users(:anton))
    characters(:anton_human).update_column(:author_id, users(:anton).id)

    3.times do |index|
      post deliver_share_character_path(characters(:anton_human)),
           params: { character_share: { email: "friend#{index}@example.com" } }
      assert_not_equal 429, response.status
    end

    post deliver_share_character_path(characters(:anton_human)),
         params: { character_share: { email: "blocked@example.com" } }

    assert_response :too_many_requests
  end

  test "throttles admin search and admin writes independently" do
    user = users(:anton)
    user.update_column(:admin, true)
    authenticate_as(user)

    50.times do |index|
      get models_search_path, params: { q: "gpt-#{index}" }
      assert_not_equal 429, response.status
    end

    get models_search_path, params: { q: "blocked" }
    assert_response :too_many_requests

    10.times do
      patch start_mcp_server_path(id: "999999")
      assert_not_equal 429, response.status
    end

    patch start_mcp_server_path(id: "999999")
    assert_response :too_many_requests
  end

  test "health check is never throttled" do
    30.times do
      get rails_health_check_path
      assert_not_equal 429, response.status
    end
  end

  test "normal authenticated get navigation remains unaffected" do
    authenticate_as(users(:anton))

    30.times do
      get root_path
      assert_not_equal 429, response.status
    end
  end

  test "mounted mission control writes are throttled while reads remain available" do
    user = users(:anton)
    user.update_column(:admin, true)
    authenticate_as(user)

    get mission_control_jobs_path
    assert_not_equal 429, response.status

    10.times do
      post "/admin/mission_control/app/applications/1/jobs/1/retry"
      assert_not_equal 429, response.status
    end

    post "/admin/mission_control/app/applications/1/jobs/1/retry"
    assert_response :too_many_requests

    get mission_control_jobs_path
    assert_not_equal 429, response.status
  end

  private

  def authenticate_as(user, password: "password123")
    post user_session_path, params: { user: { email: user.email, password: } }
    assert_not_equal 429, response.status
  end

  def direct_upload_blob_params(suffix)
    body = "blob-#{suffix}"

    {
      byte_size: body.bytesize,
      checksum: Base64.strict_encode64(Digest::MD5.digest(body)),
      content_type: "text/plain",
      filename: "upload-#{suffix}.txt"
    }
  end
end
