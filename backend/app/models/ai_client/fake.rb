# APIを呼ばずに、決まった形式の応答を返す（AI_PROVIDER=fake。E2Eとキーなしの動作確認用）。
# 何を作るかはスキーマで決める。メモの先頭を写すだけで、AIの判断は入っていない
module AiClient
  class Fake
    def complete(system:, user:, schema:)
      properties = schema[:properties]
      json =
        if properties.key?(:cases)
          similar_troubles(user)
        elsif properties.key?(:response_type)
          response_draft(user)
        else
          defect_draft(user)
        end
      Response.new(json: json, input_tokens: 0, output_tokens: 0)
    end

    private

    def memo_of(user)
      user[%r{<memo>\n(.*?)\n</memo>}m, 1].to_s.strip
    end

    def defect_draft(user)
      memo = memo_of(user)
      {
        "title" => "【AI下書き（ダミー）】#{memo.lines.first.to_s.strip.first(30)}",
        "description" => memo,
        "priority" => "medium",
        "priority_reason" => "ダミーの応答のため、優先度は中にしています。",
        "possible_causes" => [ "ダミーの応答のため、推定原因はありません" ],
        "check_points" => [ "ダミーの応答のため、確認したい点はありません" ]
      }
    end

    def response_draft(user)
      {
        "response_type" => "investigation",
        "description" => "【AI下書き（ダミー）】#{memo_of(user)}",
        "used_materials" => "",
        "check_points" => [ "ダミーの応答のため、確認したい点はありません" ]
      }
    end

    # 先頭の候補（いちばん関連の深いもの）を、似ているものとして返す。候補がなければ空
    def similar_troubles(user)
      id = user[/<candidate id="(\d+)"/, 1]
      cases = id ? [ { "trouble_id" => id.to_i, "memo_symptom" => "ダミー", "candidate_symptom" => "ダミー", "same_symptom" => true, "similarity" => "ダミーの応答のため、先頭の候補を返しています", "how_handled" => "ダミーの応答のため、対応の要約はありません" } ] : []
      { "cases" => cases }
    end
  end
end
