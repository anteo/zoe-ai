Rails.configuration.to_prepare do
  ActiveJob::Serializers.add_serializers AI::SentenceSplitter::Chunk::Serializer
end
