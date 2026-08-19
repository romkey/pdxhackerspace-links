class AddHostnameToThings < ActiveRecord::Migration[8.1]
  IPV4_REGEX = /\A(?:\d{1,3}\.){3}\d{1,3}\z/
  HOSTNAME_REGEX = /\A(?=.{1,253}\z)(?!-)[a-zA-Z0-9-]{1,63}(?<!-)(?:\.(?!-)[a-zA-Z0-9-]{1,63}(?<!-))*\z/

  def up
    add_column :things, :hostname, :string

    Thing.reset_column_information
    Thing.find_each do |thing|
      value = thing.ip_address.to_s.strip
      next if value.blank?
      next if value.match?(IPV4_REGEX)

      next unless value.match?(HOSTNAME_REGEX)

      thing.update_columns(hostname: value, ip_address: nil)
    end
  end

  def down
    Thing.reset_column_information
    Thing.where.not(hostname: [ nil, "" ]).find_each do |thing|
      next if thing.ip_address.present?

      thing.update_columns(ip_address: thing.hostname, hostname: nil)
    end

    remove_column :things, :hostname
  end
end
