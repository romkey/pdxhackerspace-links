class AddKeyToThings < ActiveRecord::Migration[8.1]
  KEY_LENGTH = 8
  KEY_ALPHABET = ("a".."z").to_a + ("0".."9").to_a
  RESERVED_KEYS = %w[login logout settings sidekiq things by_beacon new edit up auth].freeze

  def up
    add_column :things, :key, :string

    Thing.reset_column_information
    Thing.find_each do |thing|
      thing.update_column(:key, generate_unique_key)
    end

    change_column_null :things, :key, false
    add_index :things, :key, unique: true
  end

  def down
    remove_index :things, :key
    remove_column :things, :key
  end

  private

  def generate_unique_key
    loop do
      key = ("a".."z").to_a.sample +
            (KEY_LENGTH - 1).times.map { KEY_ALPHABET[SecureRandom.random_number(KEY_ALPHABET.size)] }.join
      next if RESERVED_KEYS.include?(key)
      next if Thing.exists?(key: key)

      return key
    end
  end
end
