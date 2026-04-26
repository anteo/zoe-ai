module AI::Actors
  class DescribeCharacter < Actor
    input :character, type: Character
    input :mode, default: :xml
    input :period_order, default: :asc
    output :description

    def call
      rows = current_band_rows
      if rows.empty?
        self.description = ""
        return
      end

      periods = grouped_periods(rows)
      self.description = render_template(periods).strip
    end

    private

    def current_band_rows
      scoped = character.fact_aggregates.bands.includes(:topic)
      return [] unless band_anchor_month

      scoped.where(anchor_month: band_anchor_month).order(:anchor_month).to_a
    end

    def grouped_periods(rows)
      rows.group_by { it.period(band_anchor_month) }
          .sort_by { period_sort_value(it.first) }
          .filter_map do |period, grouped_rows|
            topics = grouped_rows.sort_by { it.topic.name }
                                .filter_map do |row|
              text = summary_for(row)
              next if text.blank?

              { name: row.topic.name, text: text }
            end

            next if topics.empty?

            { title: period_title_for(grouped_rows.first), from: period.begin, to: period.end, topics: topics }
          end
    end

    def render_template(periods)
      path = Rails.root.join("app/views/ai/actors/describe_character/#{mode_name}.txt.erb")
      unless File.exist?(path)
        raise ArgumentError, "Unsupported describe-character mode: #{mode.inspect}"
      end

      ERB.new(File.read(path), trim_mode: "-").result_with_hash(periods:)
    end

    def period_sort_value(period)
      value = period.begin
      period_order.to_sym == :desc ? -value.jd : value.jd
    end

    def mode_name
      mode.to_s
    end

    def summary_for(row)
      row.summary.presence || fallback_body_for(row)
    end

    def fallback_body_for(row)
      if row.band?
        text = row.source_records.map { strip_month_heading(it.summary.presence || it.body.to_s) }
                                .reject(&:blank?)
                                .join("\n\n")
        return text if text.present?
      end

      strip_month_heading(row.body.to_s)
    end

    def strip_month_heading(text)
      text.lines.reject { |line| line.start_with?("## ") }.join.strip
    end

    def period_title_for(row)
      if (match = row.kind.match(/\Ayear_(\d{4})\z/))
        return I18n.t(:text_fact_period_year, year: match[1])
      end

      I18n.t(:"text_fact_period_#{row.kind}", default: row.kind)
    end

    def band_anchor_month
      @band_anchor_month ||= character.fact_aggregates.bands.latest_anchor_month
    end
  end
end
