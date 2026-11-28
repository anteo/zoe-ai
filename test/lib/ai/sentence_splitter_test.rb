require "test_helper"

class SentenceSplitterTest < ActiveSupport::TestCase
  test "splits plain prose within the bubble limit" do
    text = "Первое предложение. Второе предложение. Третье предложение."

    assert_equal [ "Первое предложение. Второе предложение.", "Третье предложение." ], split(text, max_messages: 2)
  end

  test "preserves paragraph breaks when grouping text into one bubble" do
    text = "Первый абзац.\n\nВторой абзац.\n\nТретий абзац."

    assert_equal [ "Первый абзац.\n\nВторой абзац.", "Третий абзац." ], split(text, max_messages: 2)
  end

  test "preserves inline code, links and emphasis within a bubble" do
    inline = "Файл `.gitignore` учитывается. **Сначала проверка. Затем запуск.** [Описание. Подробности](https://example.com/a.b)."
    parts = split("Начало.\n\n#{inline}\n\nГотово.")
    html = parts.map { |part| MarkdownRenderer.build.render(part) }.join

    assert_includes html, "<code>.gitignore</code>"
    assert_includes html, "<strong>Сначала проверка. Затем запуск.</strong>"
    assert_includes html, ">Описание. Подробности</a>"
    assert_operator parts.size, :>, 1
  end

  test "keeps backtick and tilde fenced blocks with blank lines intact" do
    [ "```", "~~~" ].each do |fence|
      example = "#{fence}sh\nif ready; then\n  echo 'Первый шаг. Второй шаг.'\n\n  echo 'Готово.'\nfi\n#{fence}"
      parts = split("Пример.\n\n#{example}\n\nКонец.")

      assert parts.any? { |part| part.include?(example) }
      assert_operator parts.size, :>, 1
    end
  end

  test "keeps list continuations, quotes and tables together" do
    list = "- Первый пункт. Продолжение.\n\n  Второй абзац пункта.\n- Последний пункт."
    quote = "> Начало цитаты. Продолжение.\n>\n> Второй абзац цитаты."
    table = "| Файл | Статус |\n| --- | --- |\n| `.gitignore` | Готово. Проверено. |"
    parts = split([ "Начало.", list, quote, table, "Конец." ].join("\n\n"))

    [ list, quote, table ].each do |block|
      assert parts.any? { |part| part.include?(block) }
    end
  end

  test "preserves reference links and indented code" do
    text = "См. [инструкцию][guide].\n\n    bash -lc 'echo ready'\n\n[guide]: https://example.com/guide"
    parts = split(text)
    html = parts.map { |part| MarkdownRenderer.build.render(part) }.join

    assert_includes html, 'href="https://example.com/guide"'
    assert_includes html, "<pre><code>"
  end

  test "leaves an HTML wrapper with its content" do
    text = "<details>\n\nПервый абзац. Второй абзац.\n\n</details>"

    assert_equal [ text ], split(text)
  end

  private

  def split(text, max_messages: 12)
    AI::SentenceSplitter.new(text, max_messages:).chunks.map(&:text)
  end
end
