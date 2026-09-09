class CreateThingAliases < ActiveRecord::Migration[8.1]
  def change
    create_table :thing_aliases do |t|
      t.references :thing, null: false, foreign_key: { to_table: :things, on_delete: :cascade }
      t.string :key
      t.string :slug

      t.timestamps
    end

    add_index :thing_aliases, :key, unique: true, where: "key IS NOT NULL"
    add_index :thing_aliases, :slug, unique: true, where: "slug IS NOT NULL"
  end
end
