# Records every save as a journal entry naming the fields and links it changed.
# Including models list JOURNAL_FIELDS and implement journal_links(before:),
# returning { key => { "label", "url", "note" } } for the links as they were
# before the pending save (before: true) or as they are now.
module Journaled
  extend ActiveSupport::Concern

  included do
    has_many :journal_entries, -> { order(created_at: :desc, id: :desc) },
             as: :journalable, dependent: :delete_all, inverse_of: :journalable

    # Override the event ("created" or "updated") and add a note to the next entry.
    attr_accessor :journal_event, :journal_message

    before_save :capture_journal_baseline, unless: :journal_suspended?
    after_save :record_journal_entry, unless: :journal_suspended?
  end

  # Journals everything done inside the block as a single entry, for work that
  # changes associated records directly rather than through save.
  def journaled(event, message: nil)
    baseline = journal_state(before: true)
    @journal_suspended = true
    result = yield
    @journal_suspended = false
    write_journal_entry(event, message, JournalEntry.diff(baseline, journal_state(before: false)))
    result
  ensure
    @journal_suspended = false
  end

  def journal_suspended?
    @journal_suspended
  end

  private

  def journal_state(before:)
    fields = self.class::JOURNAL_FIELDS.index_with do |field|
      value = if before && new_record?
        self.class.column_defaults[field]
      elsif before
        attribute_in_database(field)
      else
        self[field]
      end
      self.class.journal_value(value)
    end

    { "fields" => fields, "links" => journal_links(before: before) }
  end

  def capture_journal_baseline
    @journal_creating = new_record?
    @journal_baseline = journal_state(before: true)
  end

  def record_journal_entry
    event = journal_event.presence || (@journal_creating ? "created" : "updated")
    details = JournalEntry.diff(@journal_baseline, journal_state(before: false))
    write_journal_entry(event, journal_message, details, always: @journal_creating)
  ensure
    @journal_baseline = nil
    self.journal_event = nil
    self.journal_message = nil
  end

  def write_journal_entry(event, message, details, always: false)
    message = message.presence || journal_default_message(event)
    return if details.empty? && message.blank? && !always

    JournalEntry.create!(
      journalable: self,
      user: Current.user,
      event: event,
      message: message,
      details: details
    )
    journal_entries.reset
  end

  def journal_default_message(_event)
    nil
  end

  class_methods do
    def journal_value(value)
      value.is_a?(String) ? value.strip.presence : value
    end

    def journal_link(label, url, note)
      { "label" => label, "url" => journal_value(url), "note" => journal_value(note) }
    end
  end
end
