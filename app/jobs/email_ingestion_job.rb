class EmailIngestionJob < ApplicationJob
  queue_as :default

  def perform
    graph_service = build_graph_service
    return unless graph_service

    creator = SupportTicketCreatorService.new(graph_service: graph_service)

    emails = graph_service.fetch_new_emails
    Rails.logger.info "[EmailIngestion] Found #{emails.count} new email(s)"

    processed = 0
    emails.each do |email_data|
      creator.process_email(email_data)
      graph_service.mark_as_read(email_data[:message_id])
      processed += 1
    rescue => e
      Rails.logger.error "[EmailIngestion] Failed to process email #{email_data[:message_id]}: #{e.message}"
      # Don't mark as read so it will be retried next run
    end

    Rails.logger.info "[EmailIngestion] Processed #{processed}/#{emails.count} email(s)"
  end

  private

  def build_graph_service
    if Rails.application.credentials.dig(:microsoft_graph, :client_id).present?
      MicrosoftGraphService.new
    else
      Rails.logger.warn "[EmailIngestion] No Microsoft Graph credentials — skipping"
      nil
    end
  end
end
