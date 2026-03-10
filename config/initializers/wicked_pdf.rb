WickedPdf.configure do |config|
  config.wkhtmltopdf = '/usr/local/bin/wkhtmltopdf'
  config.layout = 'pdf'
  config.log_level = :warn
end
