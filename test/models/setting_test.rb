require "test_helper"

class SettingTest < ActiveSupport::TestCase
  teardown do
    Setting::CHANGE_HOOKS.clear
    Setting.invalidate_cache!
    Setting.instance_variable_set(:@_hooks_synced_at, nil)
    Setting.instance_variable_set(:@_hooks_synced_keys, nil)
  end

  # ── Defaults ────────────────────────────────────────────────────────────────

  test "returns default when no DB row and no ENV override" do
    assert_equal 5000, Setting.ui.flash_timeout_ms
  end

  # ── DB persistence ──────────────────────────────────────────────────────────

  test "save persists value to DB" do
    Setting.ui.update(flash_timeout_ms: 9_000)
    Setting.invalidate_cache!
    assert_equal 9_000, Setting.ui.flash_timeout_ms
  end

  test "save returns true on success" do
    assert Setting.ui.update(flash_timeout_ms: 3_000)
  end

  test "updating single mailer key does not query unrelated keys" do
    Setting.mailer.update(from: "before-select-check@example.com")

    selects = capture_settings_lookup_selects do
      Setting.mailer.update(from: "selective@example.com")
    end

    assert_equal 1, selects.size
    assert_includes selects.first, "FROM \"settings\" WHERE"
    assert_includes selects.first, "\"settings\".\"scope\""
    assert_includes selects.first, "\"settings\".\"key\""
  end

  test "updating with unchanged value skips hook firing and db writes" do
    Setting.mailer.update(from: "same@example.com")
    existing = Setting.find_by!(scope: "mailer", key: "from")
    initial_updated_at = existing.updated_at

    calls = []
    Setting.on_change(:mailer) { calls << :mailer }

    travel 1.second do
      Setting.mailer.update(from: "same@example.com")
    end

    existing.reload
    assert_equal initial_updated_at, existing.updated_at
    assert_equal [], calls
  end

  test "save returns false and does not persist when invalid" do
    result = Setting.mailer.smtp.update(port: -1)
    assert_not result
    Setting.invalidate_cache!
    assert_equal 1025, Setting.mailer.smtp.port  # default unchanged
  end

  # ── ENV override ────────────────────────────────────────────────────────────

  test "ENV value takes precedence over DB value" do
    Setting.ui.update(flash_timeout_ms: 1_000)

    with_env("ZOE_UI__FLASH_TIMEOUT_MS" => "7_777") do
      assert_equal 7_777, Setting.ui.flash_timeout_ms
    end
  end

  test "ENV value takes precedence over default" do
    with_env("ZOE_UI__FLASH_TIMEOUT_MS" => "42") do
      assert_equal 42, Setting.ui.flash_timeout_ms
    end
  end

  # ── readonly? ───────────────────────────────────────────────────────────────

  test "attr is readonly when ENV key present" do
    with_env("ZOE_UI__FLASH_TIMEOUT_MS" => "42") do
      assert Setting.ui.flash_timeout_ms_readonly?
    end
  end

  test "attr is not readonly when ENV key absent" do
    assert_not Setting.ui.flash_timeout_ms_readonly?
  end

  test "save does not write readonly attr to DB" do
    with_env("ZOE_UI__FLASH_TIMEOUT_MS" => "42") do
      proxy = Setting.ui
      proxy.flash_timeout_ms = 9_999
      proxy.save
    end

    # After ENV is gone, DB should not have been written — default remains
    Setting.invalidate_cache!
    assert_equal 5_000, Setting.ui.flash_timeout_ms
  end

  # ── static? ─────────────────────────────────────────────────────────────────

  test "static attr returns true for static: true settings" do
    assert Setting.app.extra_hosts_static?
  end

  test "non-static attr returns false" do
    assert_not Setting.app.host_static?
  end

  # ── Type coercion ───────────────────────────────────────────────────────────

  test "integer setting coerces to Integer" do
    Setting.events.update(maximum_count: 42)
    assert_kind_of Integer, Setting.events.maximum_count
    assert_equal 42, Setting.events.maximum_count
  end

  test "boolean setting coerced from ENV string" do
    with_env("ZOE_AI__DEBUG" => "true") do
      assert_equal true, Setting.ai.debug?
    end
  end

  # ── watch / on_change ───────────────────────────────────────────────────────

  test "watch calls block immediately" do
    calls = []
    Setting.watch(:ui) { calls << :immediate }
    assert_equal 1, calls.size
  end

  test "on_change does not call block immediately" do
    calls = []
    Setting.on_change(:ui) { calls << :deferred }
    assert_equal 0, calls.size
  end

  test "hook registered with on_change fires after save" do
    calls = []
    Setting.on_change(:ui) { calls << :fired }
    Setting.ui.update(flash_timeout_ms: 2_000)
    assert_equal 1, calls.size
  end

  test "watch hook fires on subsequent saves" do
    calls = []
    Setting.watch(:ui) { calls << :fired }
    calls.clear  # discard the immediate call

    Setting.ui.update(flash_timeout_ms: 2_000)
    Setting.ui.update(flash_timeout_ms: 3_000)
    assert_equal 2, calls.size
  end

  # ── Hook bubbling ────────────────────────────────────────────────────────────

  test "saving nested scope fires ancestor hook" do
    ai_calls = []
    Setting.on_change(:ai) { ai_calls << :fired }

    Setting.ai.providers.openrouter.update(api_key: "sk-test")

    assert_equal 1, ai_calls.size
  end

  test "saving nested scope fires intermediate scope hook" do
    providers_calls = []
    Setting.on_change(:"ai.providers") { providers_calls << :fired }

    Setting.ai.providers.deepseek.update(api_key: "sk-test")

    assert_equal 1, providers_calls.size
  end

  test "saving parent scope with multiple providers fires intermediate hook once" do
    providers_calls = []
    Setting.on_change(:"ai.providers") { providers_calls << :fired }

    Setting.ai.update(
      providers_attributes: {
        openrouter_attributes: { api_key: "sk-openrouter" },
        deepseek_attributes: { api_key: "sk-deepseek" }
      }
    )

    assert_equal 1, providers_calls.size
  end

  test "saving top-level scope does not fire unrelated hooks" do
    calls = []
    Setting.on_change(:mailer) { calls << :fired }

    Setting.ui.update(flash_timeout_ms: 2_000)

    assert_equal 0, calls.size
  end

  test "updating mailer.from does not fire smtp hook" do
    smtp_calls = []
    Setting.on_change(:"mailer.smtp") { smtp_calls << :fired }

    Setting.mailer.update(from: "from-only@example.com")

    assert_equal [], smtp_calls
  end

  # ── Nested scope access ──────────────────────────────────────────────────────

  test "nested provider scopes are accessible" do
    providers = Setting.ai.providers
    assert_respond_to providers, :openrouter
    assert_respond_to providers, :deepseek
    assert_respond_to providers, :ollama
  end

  test "deeply nested scope reads and writes" do
    Setting.ai.providers.openrouter.update(api_key: "sk-openrouter")
    Setting.invalidate_cache!
    assert_equal "sk-openrouter", Setting.ai.providers.openrouter.api_key
  end

  test "saving parent scope persists nested settings" do
    result = Setting.mailer.update(
      from: "zoe@example.com",
      smtp_attributes: {
        address: "smtp.example.com",
        port: 587
      }
    )

    assert result
    Setting.invalidate_cache!
    assert_equal "zoe@example.com", Setting.mailer.from
    assert_equal "smtp.example.com", Setting.mailer.smtp.address
    assert_equal 587, Setting.mailer.smtp.port
  end

  test "saving parent scope with invalid nested settings fails and does not persist" do
    Setting.mailer.update(from: "before@example.com")

    result = Setting.mailer.update(
      from: "after@example.com",
      smtp_attributes: { port: 99_999 }
    )

    assert_not result
    Setting.invalidate_cache!
    assert_equal "before@example.com", Setting.mailer.from
    assert_equal 1025, Setting.mailer.smtp.port
  end

  test "ENV override works for deeply nested scope" do
    with_env("ZOE_AI__PROVIDERS__OPENROUTER__API_KEY" => "sk-from-env") do
      assert_equal "sk-from-env", Setting.ai.providers.openrouter.api_key
      assert Setting.ai.providers.openrouter.api_key_readonly?
    end
  end

  # ── Nested validations ───────────────────────────────────────────────────────

  test "smtp port validation rejects out-of-range value" do
    smtp = Setting.mailer.smtp
    smtp.port = 99_999
    assert_not smtp.valid?
    assert smtp.errors[:port].any?
  end

  test "smtp port validation accepts valid port" do
    smtp = Setting.mailer.smtp
    smtp.port = 587
    assert smtp.valid?
  end

  test "parent mailer proxy propagates smtp validation errors" do
    mailer = Setting.mailer
    # Persist an invalid port so child proxy reads it back
    Setting.find_or_initialize_by(scope: "mailer.smtp", key: "port")
           .tap { |s| s.value = "99999" }
           .save!(validate: false)
    Setting.invalidate_cache!

    assert_not mailer.valid?
    assert mailer.errors[:"smtp.port"].any?
  end

  # ── Cache ────────────────────────────────────────────────────────────────────

  test "cached_data is reused within the same request" do
    first  = Setting.cached_data.object_id
    second = Setting.cached_data.object_id
    assert_equal first, second
  end

  test "invalidate_cache! causes fresh load" do
    Setting.ui.update(flash_timeout_ms: 1_111)
    Setting.invalidate_cache!
    assert_equal 1_111, Setting.ui.flash_timeout_ms
  end

  # ── Worker hook sync ────────────────────────────────────────────────────────

  test "sync_hooks_if_stale! runs hooks after db update without local save hooks" do
    calls = []
    Setting.on_change(:ui) { calls << :ui }

    Setting.sync_hooks_if_stale!
    calls.clear

    Setting.find_or_initialize_by(scope: "ui", key: "flash_timeout_ms")
           .tap { |row| row.value = "4321" }
           .save!

    Setting.sync_hooks_if_stale!

    assert_equal [ :ui ], calls
  end

  test "sync_hooks_if_stale! detects deletion via key diff" do
    calls = []
    Setting.on_change(:ui) { calls << :ui }

    Setting.ui.update(flash_timeout_ms: 2_222)
    Setting.sync_hooks_if_stale!
    calls.clear

    Setting.where(scope: "ui", key: "flash_timeout_ms").delete_all
    Setting.sync_hooks_if_stale!

    assert_equal [ :ui ], calls
  end

  test "sync_hooks_if_stale! replays registered hooks on full-table deletion" do
    ui_calls = []
    ai_calls = []
    Setting.on_change(:ui) { ui_calls << :ui }
    Setting.on_change(:ai) { ai_calls << :ai }

    Setting.ui.update(flash_timeout_ms: 3_333)
    Setting.ai.update(request_timeout: 45)
    Setting.sync_hooks_if_stale!
    ui_calls.clear
    ai_calls.clear

    Setting.delete_all
    Setting.sync_hooks_if_stale!

    assert_equal [ :ui ], ui_calls
    assert_equal [ :ai ], ai_calls
  end

  private

  def with_env(pairs, &block)
    old_values = pairs.transform_values { |_| nil }

    pairs.each do |key, value|
      old_values[key] = ENV[key]
      ENV[key] = value
    end

    Setting.invalidate_cache!
    block.call
  ensure
    old_values.each { |key, old| old.nil? ? ENV.delete(key) : ENV[key] = old }
    Setting.invalidate_cache!
  end

  def capture_settings_lookup_selects
    selects = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      sql = payload[:sql]
      next unless sql.is_a?(String)
      next unless sql.include?("FROM \"settings\" WHERE")
      next unless sql.include?("\"settings\".\"scope\"")
      next unless sql.include?("\"settings\".\"key\"")
      next unless sql.include?("LIMIT")

      selects << sql
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      yield
    end

    selects
  end
end
