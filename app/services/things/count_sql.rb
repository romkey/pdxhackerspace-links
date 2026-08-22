module Things
  module CountSql
    LINKS = <<~SQL.squish
      (SELECT COUNT(*)
       FROM thing_links
       WHERE thing_links.thing_id = things.id
         AND thing_links.url IS NOT NULL
         AND thing_links.url <> '')
    SQL

    PHOTOS = <<~SQL.squish
      (SELECT COUNT(*)
       FROM active_storage_attachments
       WHERE active_storage_attachments.record_type = 'Thing'
         AND active_storage_attachments.record_id = things.id
         AND active_storage_attachments.name = 'photos')
    SQL

    AR_MARKER = <<~SQL.squish
      (SELECT 1
       FROM active_storage_attachments
       WHERE active_storage_attachments.record_type = 'Thing'
         AND active_storage_attachments.record_id = things.id
         AND active_storage_attachments.name = 'ar_anchor'
       LIMIT 1)
    SQL
  end
end
