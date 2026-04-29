module SettingConcern
  extend ActiveSupport::Concern

  included do
    ENV_PREFIX = "ZOE_"
    SCOPE_DEFINITIONS = {}
    CHANGE_HOOKS = Hash.new { |h, k| h[k] = [] }
    HOOKS_SYNC_MUTEX = Mutex.new

    validates :scope, :key, presence: true
    validates :key, uniqueness: { scope: :scope }

    extend SettingConcern::ScopeProxyBehavior
    extend SettingConcern::ClassMethods
  end
end
