class CreateThingTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :thing_templates do |t|
      t.string :name, null: false
      t.string :thing_name
      t.text :description
      t.text :notes
      t.string :owner
      t.string :manufacturer
      t.string :model
      t.string :manufacturer_url
      t.boolean :public_access, null: false, default: false
      t.jsonb :links, null: false, default: []

      t.timestamps
    end

    add_index :thing_templates, "lower(name)", unique: true, name: "index_thing_templates_on_lower_name"
  end
end
