class CreateThingRelationships < ActiveRecord::Migration[8.1]
  def change
    create_table :thing_relationships do |t|
      t.references :thing, null: false, foreign_key: { to_table: :things, on_delete: :cascade }
      t.references :related_thing, null: false, foreign_key: { to_table: :things, on_delete: :cascade }
      t.text :note

      t.timestamps
    end

    add_index :thing_relationships, %i[thing_id related_thing_id], unique: true
  end
end
