class CreateJournalEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :journal_entries do |t|
      t.references :journalable, polymorphic: true, null: false, index: false
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :event, null: false
      t.string :message
      t.jsonb :details, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_index :journal_entries, %i[journalable_type journalable_id created_at],
              name: "index_journal_entries_on_journalable_and_created_at"
  end
end
