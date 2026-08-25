namespace :photos do
  desc "Preprocess hero and thumb variants for all thing photos"
  task backfill_variants: :environment do
    count = 0
    ActiveStorage::Attachment.where(record_type: "Thing", name: "photos").find_each do |attachment|
      attachment.variant(:hero).processed
      attachment.variant(:thumb).processed
      count += 1
    rescue StandardError => error
      warn "Skipping photo #{attachment.id}: #{error.message}"
    end
    puts "Processed variants for #{count} photos."
  end
end
