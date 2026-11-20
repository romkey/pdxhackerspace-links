class CreateApiKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :api_keys do |t|
      t.string :name, null: false
      t.string :token_digest, null: false
      t.string :token_prefix, null: false
      t.datetime :last_used_at
      t.references :user, foreign_key: { on_delete: :nullify }
      t.timestamps
    end

    add_index :api_keys, "lower(name)", unique: true, name: "index_api_keys_on_lower_name"
    add_index :api_keys, :token_digest, unique: true
  end
end
