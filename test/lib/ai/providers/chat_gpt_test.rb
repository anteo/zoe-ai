require "test_helper"
require "tempfile"

class AI::Providers::ChatGPTTest < ActiveSupport::TestCase
  setup do
    config = RubyLLM::Configuration.new
    config.chatgpt_api_base = "http://127.0.0.1:10531/v1"
    config.chatgpt_enabled = true
    config.chatgpt_request_timeout = 300
    @provider = AI::Providers::ChatGPT.new(config)
  end

  test "normalizes image sizes to GPT Image 2 constraints" do
    assert_equal "816x816", @provider.normalize_image_size("512x512")
    assert_equal "1024x1024", @provider.normalize_image_size("1024x1024")
    assert_equal "2048x2048", @provider.normalize_image_size("2048x2048")
    assert_equal "2880x2880", @provider.normalize_image_size("4096x4096")
    assert_equal "3840x2160", @provider.normalize_image_size("7281x4096")
  end

  test "normalizes the common Draw aspect ratios" do
    {
      "1:1" => "2048x2048",
      "2:3" => "1365x2048",
      "3:2" => "3072x2048",
      "16:9" => "3640x2048"
    }.each do |ratio, size|
      requested_width, requested_height = size.split("x").map(&:to_i)
      width, height = @provider.normalize_image_size(size).split("x").map(&:to_i)

      assert_equal 0, width % 16, ratio
      assert_equal 0, height % 16, ratio
      assert_in_delta requested_width.fdiv(requested_height), width.fdiv(height), 0.01, ratio
      assert_operator width * height, :>=, AI::Providers::ChatGPT::MIN_PIXELS, ratio
      assert_operator width * height, :<=, AI::Providers::ChatGPT::MAX_PIXELS, ratio
    end
  end

  test "rejects unsupported aspect ratios" do
    error = assert_raises(ArgumentError) { @provider.normalize_image_size("4096x1024") }

    assert_match "between 1:3 and 3:1", error.message
  end

  test "exposes a provider-qualified image model" do
    model = @provider.list_models.first

    assert_equal "chatgpt/gpt-image-2", model.id
    assert_equal "chatgpt", model.provider
    assert_equal %w[text image], model.modalities.input
    assert_equal %w[image], model.modalities.output
  end

  test "converts the qualified model and size in generation payloads" do
    payload = @provider.render_image_payload(
      "Draw a cat",
      model: "chatgpt/gpt-image-2",
      size: "4096x4096"
    )

    assert_equal "gpt-image-2", payload[:model]
    assert_equal "2880x2880", payload[:size]
  end

  test "builds an image edit payload from reference images" do
    Tempfile.create([ "reference", ".png" ]) do |file|
      file.binmode
      file.write("\x89PNG\r\n\x1A\n")
      file.flush

      payload = @provider.render_image_payload(
        "Keep the subject and change the background",
        model: "chatgpt/gpt-image-2",
        size: "2048x2048",
        with: [ file.path ]
      )

      assert_equal "gpt-image-2", payload[:model]
      assert_equal "2048x2048", payload[:size]
      assert_equal 1, payload[:image].size
    end
  end
end
