Rails.configuration.to_prepare do
  ActiveJob::Serializers.add_serializers AI::SentenceSplitter::Sentence::Serializer
end
