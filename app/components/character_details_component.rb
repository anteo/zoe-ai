# frozen_string_literal: true

class CharacterDetailsComponent < ApplicationComponent
  attr_reader :character, :refresh

  def initialize(character:, refresh: nil)
    @character = character
    @refresh = refresh
  end

  def type_label
    if character.ai?
      t(:label_ai)
    elsif character.third_party?
      t(:label_other)
    else
      t(:label_human)
    end
  end

  def type_badge_class
    if character.ai?
      "badge-primary"
    elsif character.third_party?
      "badge-neutral"
    else
      "badge-warning"
    end
  end

  def deletable?
    !character.is_default? && character.id != helpers.current_user.main_character_id
  end

  def sections
    [
      ({ key: "description", label: t(:label_description), icon_class: "icon-[lucide--file-text]", count: nil, badge_target: nil } if character.description.present?),
      ({ key: "instructions", label: t(:label_instructions), icon_class: "icon-[lucide--sparkles]", count: instructions_count, badge_target: "instructionsCountBadge" } if character.ai?),
      ({ key: "facts", label: t(:label_facts), icon_class: "icon-[lucide--brain]", count: facts_count, badge_target: nil } if character.facts.any?),
      { key: "images", label: t(:label_images), icon_class: "icon-[lucide--images]", count: images_count, badge_target: "imagesCountBadge" }
    ].compact
  end

  def default_section
    sections.first[:key]
  end

  def section_frame_id(section)
    "character-section-#{section}"
  end

  def section_path(section)
    helpers.section_character_path(character, section: section, refresh: refresh)
  end

  private

  def facts_count
    @facts_count ||= character.facts.count
  end

  def images_count
    @images_count ||= character.images.attachments.count
  end

  def instructions_count
    @instructions_count ||= character.instructions.count
  end
end
