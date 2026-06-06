class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :name, null: false
      t.string :provider
      t.string :uid
      t.string :password_digest

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, %i[provider uid], unique: true, where: "provider IS NOT NULL AND uid IS NOT NULL"
  end
end
