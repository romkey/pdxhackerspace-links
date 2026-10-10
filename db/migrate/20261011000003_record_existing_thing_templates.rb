# Templates saved before journals existed get a starting entry holding their
# current contents, so refreshing things later knows what the template said.
class RecordExistingThingTemplates < ActiveRecord::Migration[8.1]
  FIELDS = %w[name thing_name description notes owner manufacturer model manufacturer_url public_access].freeze
  LINK_LABELS = { "wiki" => "Wiki", "slack" => "Slack", "where" => "Where", "ar" => "AR" }.freeze

  class Template < ActiveRecord::Base
    self.table_name = "thing_templates"
  end

  class Entry < ActiveRecord::Base
    self.table_name = "journal_entries"
  end

  def up
    Template.find_each do |template|
      fields = FIELDS.each_with_object({}) do |field, hash|
        value = template[field]
        hash[field] = [ nil, value ] unless value.nil? || value == "" || value == false
      end
      added = Array(template.links).map do |data|
        key = data["link_type"] == "custom" ? "custom:#{data['title'].to_s.strip.downcase}" : data["link_type"]
        label = data["link_type"] == "custom" ? data["title"] : LINK_LABELS[data["link_type"]]
        { "key" => key, "label" => label, "url" => data["url"].presence, "note" => data["note"].presence }
      end
      details = { "fields" => fields }
      details["links"] = { "added" => added } if added.any?

      Entry.create!(
        journalable_type: "ThingTemplate",
        journalable_id: template.id,
        event: "recorded",
        message: "Journal started",
        details: details,
        created_at: Time.current
      )
    end
  end

  def down
    Entry.where(journalable_type: "ThingTemplate", event: "recorded").delete_all
  end
end
