# frozen_string_literal: true

module Patches
  class Error < StandardError; end

  class << self
    def register(target_names)
      @target_names ||= []
      @target_names |= Array(target_names)
    end

    def apply!
      target_names.each do |target_name|
        target = target_name.safe_constantize
        next unless target

        patch = patch_constant_name_for(target_name).safe_constantize
        raise Error, "Missing patch constant for #{target_name}: #{patch_constant_name_for(target_name)}" unless patch

        next if target < patch

        target.prepend(patch)
      end
    end

    private

    def target_names
      @target_names || []
    end

    def patch_constant_name_for(target_name)
      "Patches::#{target_name}Patch"
    end
  end
end
