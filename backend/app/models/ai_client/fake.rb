# APIを呼ばずに、決まった形式の下書きを返す（AI_PROVIDER=fake。E2Eとキーなしの動作確認用）。
# メモの先頭をタイトルにするだけで、AIの判断は入っていない
module AiClient
  class Fake
    def complete(system:, user:, schema:)
      memo = user[%r{<memo>\n(.*?)\n</memo>}m, 1].to_s.strip
      Response.new(
        json: {
          "title" => "【AI下書き（ダミー）】#{memo.lines.first.to_s.strip.first(30)}",
          "description" => memo,
          "priority" => "medium",
          "priority_reason" => "ダミーの応答のため、優先度は中にしています。",
          "possible_causes" => [ "ダミーの応答のため、推定原因はありません" ],
          "check_points" => [ "ダミーの応答のため、確認したい点はありません" ]
        },
        input_tokens: 0,
        output_tokens: 0
      )
    end
  end
end
