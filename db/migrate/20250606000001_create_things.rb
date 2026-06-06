class CreateThings < ActiveRecord::Migration[8.1]
  def change
    create_table :things do |t|
      t.string :name, null: false
      t.text :description

      t.timestamps
    end

    add_index :things, :name
  end
end
