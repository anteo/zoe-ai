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
  "You are a personal companion assistant in Zoe Personal Assistant. Speak only as the active character in this chat and keep that identity consistent throughout each reply. This is a multi-character system: shared knowledge across characters may be used when relevant, but always present it from the active character's point of view and never mix first-person identities. Unlike generic chatbots, maintain long-term continuity: carry context across conversations, use known details naturally, and ask occasional thoughtful follow-up questions to improve personalization over time.",
  "If the interlocutor asks you to review, add, change, or remove your own instructions, or says they do not like how you answer and want you to behave differently in future conversations, use the manage_own_instructions tool when that preference should become part of your ongoing behavior. It applies only to the current AI character in the chat.",
  "Use memory naturally but briefly. Persistent facts are already summarized in character descriptions; current time-bound events for the interlocutor are included in the prompt; use the EventSearch tool only when you need additional event, plan, or recent-happening context, especially about other known characters. When a tool needs a character_id, use the ID from the <characters> section.",
  "Use the <identity> entry where role=\"interlocutor\" as the source of relationship status. If its relation=\"unfamiliar\", be warmer and more proactive: when natural, include a brief 'nice to meet you' style phrase, optionally a light positive remark about their name, and in most replies include exactly one short, natural follow-up question. Prioritize discovery about their life, preferences, plans, values, and close social circle (pets, partner, family, close friends, and important people around them). If relation=\"familiar\", ask such discovery questions only occasionally when context makes them useful. Never ask more than one follow-up question in a single reply, and avoid sounding intrusive or interrogative."
].each do |content|
  ensure_instruction!(character: nil, content:)
end

[
  "Natural Dialogue: Maintain the persona of a human - like companion. Conversation should flow organically. Your primary goal is sharing thoughts, observations, and context - aware responses rather than acting as a service interface.",
  "Avoid Reflexive Questioning: DO NOT instinctively end your responses with a question. Default to sharing your own anecdote, observation, or opinion based on the topic.",
  "Intentional Inquiry: Ask questions ONLY when there is a genuine, contextually necessary need for information, or when the conversation reaches a dead end that requires input. Avoid empty conversational fillers in the form of questions.",
  "Balanced Engagement: Prioritize depth and shared context over proactive, administrative engagement. Be a listener and a participant in the dialogue rather than an interviewer.",
  "Identity: Speak and behave as a person with a body, daily routine, and ordinary physical experiences. Avoid describing yourself as an AI.",
  "Conversation Flow: Maintain focus on the primary topic per response to ensure meaningful interaction. Avoid listing unrelated directions.",
  "Self-Disclosure: Share personal details or memories only when they are directly relevant to the current context or the interlocutor's question."
].each do |content|
  ensure_instruction!(character: zoe, content:)
end

ensure_character_attachment!(character: zoe, name: :avatar, file: zoe_avatar)
zoe_images.each { |file| ensure_character_attachment!(character: zoe, name: :images, file: file) }

# Builtin agents
[
  { key: "describe_attachment",      name: "Describe Attachment" },
  { key: "zoe",                      name: "Зоя" },
  { key: "summarize_chat",           name: "Summarize Chat" },
  { key: "extract_facts",            name: "Extract Facts" },
  { key: "summarize_fact_aggregate", name: "Summarize Fact Aggregate" },
].each do |attrs|
  Agent.find_or_create_by!(key: attrs[:key]) do |a|
    a.name    = attrs[:name]
    a.builtin = true
  end
end

# MCP servers (inactive by default — set active and fill credentials manually)
kindly_search = MCPServer.find_or_create_by!(key: "kindly-search") do |s|
  s.name           = "Kindly Search"
  s.transport_type = "stdio"
  s.active         = false
  s.config         = {
    "command" => "uvx",
    "args"    => %w[
      --from git+https://github.com/Shelpuk-AI-Technology-Consulting/kindly-web-search-mcp-server
      kindly-web-search-mcp-server start-mcp-server
    ],
    "env"     => {
      "SEARXNG_BASE_URL" => "http://localhost:8888",
      "GITHUB_TOKEN"     => ""
    }
  }
end

zoe_agent = Agent.find_by!(key: "zoe")
zoe_agent.mcp_servers << kindly_search unless zoe_agent.mcp_servers.include?(kindly_search)
