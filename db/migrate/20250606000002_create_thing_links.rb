class CreateThingLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :thing_links do |t|
      t.references :thing, null: false, foreign_key: true
      t.string :link_type, null: false
      t.string :title
      t.string :url
      t.integer :position

      t.timestamps
    end

    add_index :thing_links, %i[thing_id link_type], unique: true,
              where: "link_type IN ('asset', 'wiki', 'slack', 'where')",
              name: "index_thing_links_on_thing_id_and_standard_link_type"
    add_index :thing_links, %i[thing_id position]
  end
end
