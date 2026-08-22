module AI
  class ModelRegistry
    KEY = "registry_version"
    MUTEX = Mutex.new
    SCOPE = "ai.models"

    class << self
      def bump_version!
        version = Setting.transaction do
          setting = Setting.lock.find_or_initialize_by(scope: SCOPE, key: KEY)
          setting.value = setting.value.to_i + 1
          setting.save!
          setting.value.to_i
        end

        Setting.invalidate_cache!
        MUTEX.synchronize { @loaded_version = version }
        version
      end

      def sync!
        version = current_version
        return if @loaded_version == version

        MUTEX.synchronize do
          version = current_version
          return if @loaded_version == version

          RubyLLM.models.load_from_database!
          @loaded_version = version
        end
      end

      private

      def current_version
        Setting.find_by(scope: SCOPE, key: KEY)&.value&.to_i || 0
      end
    end
  end
end
