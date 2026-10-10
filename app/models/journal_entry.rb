# One recorded change to a thing or template: what happened, who did it, and
# which fields and links changed. Details look like
#   { "fields" => { "owner" => [ "old", "new" ] },
#     "links" => { "added" => [ link ], "removed" => [ link ],
#                  "modified" => [ { "key", "label", "changes" => { "url" => [ old, new ] } } ] },
#     "things" => [ { "id", "name" } ] }
# where a link is { "key", "label", "url", "note" }.
class JournalEntry < ApplicationRecord
  LINK_ATTRIBUTES = %w[label url note].freeze

  belongs_to :journalable, polymorphic: true
  belongs_to :user, optional: true

  validates :event, presence: true

  scope :chronological, -> { reorder(:created_at, :id) }

  # Compares two snapshots of the form
  #   { "fields" => { name => value }, "links" => { key => { "label", "url", "note" } } }
  def self.diff(before, after)
    details = {}

    fields = after["fields"].each_with_object({}) do |(name, value), changes|
      old = before["fields"][name]
      changes[name] = [ old, value ] unless old == value
    end
    details["fields"] = fields if fields.any?

    links = diff_links(before["links"], after["links"])
    details["links"] = links if links.any?

    details
  end

  def self.diff_links(before, after)
    added = (after.keys - before.keys).map { |key| after[key].merge("key" => key) }
    removed = (before.keys - after.keys).map { |key| before[key].merge("key" => key) }
    modified = (after.keys & before.keys).filter_map do |key|
      changes = LINK_ATTRIBUTES.each_with_object({}) do |attribute, hash|
        old = before[key][attribute]
        new = after[key][attribute]
        hash[attribute] = [ old, new ] unless old == new
      end
      { "key" => key, "label" => after[key]["label"], "changes" => changes } if changes.any?
    end

    { "added" => added, "removed" => removed, "modified" => modified }.select { |_kind, list| list.any? }
  end

  def field_changes
    details.fetch("fields", {})
  end

  def links_added
    details.dig("links", "added") || []
  end

  def links_removed
    details.dig("links", "removed") || []
  end

  def links_modified
    details.dig("links", "modified") || []
  end

  def things
    details.fetch("things", [])
  end
end
