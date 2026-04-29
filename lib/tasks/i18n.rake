require "psych"

namespace :i18n do
  desc "Sort locale YAML keys recursively"
  task sort: :environment do
    locale_files = Dir[Rails.root.join("config/locales/*.yml")]

    sorter = lambda do |value|
      case value
      when Hash
        value.keys.sort_by(&:to_s).each_with_object({}) do |key, sorted|
          sorted[key] = sorter.call(value[key])
        end
      when Array
        value.map { |item| sorter.call(item) }
      else
        value
      end
    end

    locale_files.each do |path|
      data = Psych.load_file(path, aliases: true)
      sorted = sorter.call(data)
      yaml = Psych.dump(sorted, indentation: 2, line_width: -1)
      yaml = yaml.sub(/\A---\s*\n/, "")

      File.write(path, yaml)
      puts "Sorted #{Pathname(path).relative_path_from(Rails.root)}"
    end
  end
end
