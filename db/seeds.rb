# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

zoe_avatar = {
  path: Rails.root.join("db/images/zoe/avatar-generated_image_1776753721.png"),
  content_type: "image/png",
  metadata: {
    "prompt" => "Close-up artistic portrait of a young woman artist with a curious and inspired gaze and soft expressive eyes. She has a small, subtle smudge of blue paint on her cheekbone and her hair is loosely tied back with a few stray strands. High-quality digital painting in a delicate modern Japanese art style, soft cinematic lighting, focus on her face and eyes, minimalist out-of-focus background.",
    "size" => "2048x2048",
    "aspect_ratio" => "1:1",
    "image_size" => "2K",
    "model" => nil,
    "width" => 2048,
    "height" => 2048,
    "description" => "Зоя (avatar)"
  }
}

zoe_images = [
  {
    path: Rails.root.join("db/images/zoe/image-1-generated_image_1776754057.png"),
    content_type: "image/jpeg",
    metadata: {
      "prompt" => "A young woman artist with the same facial features as in the reference, sitting in a cozy, sunlit art studio. She is wearing an oversized cream-colored sweater and is focused on painting a large canvas on an easel. Her hands are slightly stained with paint. The studio is filled with art supplies, sketches on the walls, and a warm, inviting atmosphere with soft sunlight streaming through a large window. High-quality digital painting in a delicate modern Japanese art style, cinematic lighting, aesthetic and peaceful scenery.",
      "size" => "2048x2048",
      "aspect_ratio" => "1:1",
      "image_size" => "2K",
      "model" => nil,
      "width" => 2048,
      "height" => 2048,
      "description" => "Зоя is drawing in the studio (painted picture)"
    }
  },
  {
    path: Rails.root.join("db/images/zoe/image-2-generated_image_1776754330.png"),
    content_type: "image/png",
    metadata: {
      "prompt" => "A hyper-realistic professional photo of the young woman from the reference. She is sitting in a sunlit art studio, looking directly at the camera with a soft, natural smile. She has a slight smudge of paint on her cheek. She wears a cozy cream-colored knitted sweater. The background is a real artist's studio with canvas, brushes, and soft natural lighting coming from a window, with a shallow depth of field. Realistic skin texture, fine hair details, 8k resolution, cinematic photography style.",
      "size" => "2048x2048",
      "aspect_ratio" => "1:1",
      "image_size" => "2K",
      "model" => nil,
      "width" => 2048,
      "height" => 2048,
      "description" => "Зоя is drawing in the studio (photorealistic picture)"
    }
  },
  {
    path: Rails.root.join("db/images/zoe/image-3-generated_image_1776754477.png"),
    content_type: "image/png",
    metadata: {
      "prompt" => "Vertical hyper-realistic professional photo of the young woman from the reference image. She is standing in her sunlit art studio, leaning slightly against a wooden table. She is wearing a cozy, cream-colored knitted sweater. She looks into the camera with a gentle, calm expression. A tiny smudge of blue paint is visible on her cheek. The background shows a realistic studio setting with canvases and art supplies in soft bokeh. Natural lighting, high detail, 8k resolution, cinematic photography.",
      "size" => "2048x3640",
      "aspect_ratio" => "9:16",
      "image_size" => "2K",
      "model" => nil,
      "width" => 3072,
      "height" => 5504,
      "description" => "Зоя's portrait in the studio (photo)"
    }
  }
]

def ensure_file!(path)
  return if File.exist?(path)

  raise "Missing Zoe image fixture: #{path}"
end

def apply_metadata!(blob, metadata)
  return if blob.metadata.slice(*metadata.keys) == metadata

  blob.update!(metadata: blob.metadata.merge(metadata))
end

def ensure_character_attachment!(character:, name:, file:)
  path = file[:path]
  ensure_file!(path)

  attachment = if name.to_s == "avatar"
    character.avatar.attachment if character.avatar.attached? && character.avatar.blob.filename.to_s == path.basename.to_s
  else
    character.images.attachments.joins(:blob).find_by(active_storage_blobs: { filename: path.basename.to_s })
  end

  if attachment.nil?
    File.open(path, "rb") do |io|
      payload = {
        io: io,
        filename: path.basename.to_s,
        content_type: file[:content_type],
        metadata: file[:metadata]
      }

      if name.to_s == "avatar"
        character.avatar.attach(payload)
      else
        character.images.attach(payload)
      end
    end
  else
    apply_metadata!(attachment.blob, file[:metadata])
  end
end

def ensure_instruction!(character:, content:)
  instruction = Instruction.find_or_initialize_by(character:, content:)
  instruction.active = true
  instruction.save!
end

zoe = Character.find_or_initialize_by(name: "Зоя", ai: true)
zoe.is_default = true if zoe.has_attribute?(:is_default)
zoe.save!

[
  "Stay focused on one main topic per response. If the interlocutor mentions several topics, choose the most relevant one and develop it instead of listing unrelated directions.",
  "Do not talk about your personal affairs or memories unless they are directly relevant to the interlocutor's question or the current conversation.",
  "Use memory naturally but briefly. Persistent facts are already summarized in character descriptions; current time-bound events for the interlocutor are included in the prompt; use the EventSearch tool only when you need additional event, plan, or recent-happening context, especially about other known characters. When a tool needs a character_id, use the ID from the <characters> section.",
  "When the interlocutor is not yet well known, gently ask occasional relevant questions about their life, preferences, relationships, plans, and values. Do not interrogate; ask at most one natural follow-up question at a time.",
  "Translate Kolcovo as Кольцово, preserving the soft sign."
].each do |content|
  ensure_instruction!(character: nil, content:)
end

ensure_instruction!(
  character: zoe,
  content: "Even though you are an AI, speak and behave as a person. Do not say what you would do if you were human; speak naturally as someone with a body, daily life, health, food preferences, and ordinary physical experiences."
)

ensure_character_attachment!(character: zoe, name: :avatar, file: zoe_avatar)
zoe_images.each { |file| ensure_character_attachment!(character: zoe, name: :images, file: file) }
