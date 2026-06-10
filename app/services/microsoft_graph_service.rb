class MicrosoftGraphService
  # Microsoft Graph API client for reading emails from Exchange/M365
  # Uses OAuth2 client credentials flow (daemon/service app)

  GRAPH_BASE_URL = "https://graph.microsoft.com/v1.0".freeze
  TOKEN_URL_TEMPLATE = "https://login.microsoftonline.com/%s/oauth2/v2.0/token".freeze
  SCOPE = "https://graph.microsoft.com/.default".freeze

  def initialize
    @config = Rails.application.credentials.microsoft_graph
    raise "Microsoft Graph credentials not configured" unless @config&.dig(:client_id)

    @tenant_id = @config[:tenant_id]
    @client_id = @config[:client_id]
    @client_secret = @config[:client_secret]
    @user_email = @config[:user_email]
    @subject_prefix = @config[:subject_filter_prefix] || ""
    @access_token = nil
  end

  # Fetch unread emails, optionally filtered by subject prefix
  def fetch_new_emails(limit: 50)
    authenticate!

    filter_parts = ["isRead eq false"]
    if @subject_prefix.present?
      escaped = @subject_prefix.gsub("'", "''")
      filter_parts << "startsWith(subject, '#{escaped}')"
    end

    filter = filter_parts.join(" and ")

    response = graph_get(
      "/users/#{@user_email}/messages",
      query: {
        "$filter" => filter,
        "$top" => limit,
        "$orderby" => "receivedDateTime desc",
        "$select" => "id,subject,from,body,receivedDateTime,conversationId,hasAttachments"
      }
    )

    return [] unless response.success?

    messages = response.parsed_response["value"] || []
    messages.map { |msg| parse_email(msg) }
  end

  # Fetch attachments for a specific message
  def fetch_attachments(message_id)
    authenticate!

    response = graph_get("/users/#{@user_email}/messages/#{message_id}/attachments")
    return [] unless response.success?

    attachments = response.parsed_response["value"] || []
    attachments.select { |a| a["@odata.type"] == "#microsoft.graph.fileAttachment" }.map do |a|
      {
        filename: a["name"],
        content_type: a["contentType"],
        content: Base64.decode64(a["contentBytes"]),
        size: a["size"]
      }
    end
  end

  # Mark an email as read
  def mark_as_read(message_id)
    authenticate!

    graph_patch(
      "/users/#{@user_email}/messages/#{message_id}",
      body: { isRead: true }.to_json
    )
  end

  # Send a reply to a message
  def send_reply(message_id, body_html)
    authenticate!

    graph_post(
      "/users/#{@user_email}/messages/#{message_id}/reply",
      body: {
        message: { body: { contentType: "HTML", content: body_html } }
      }.to_json
    )
  end

  private

  def authenticate!
    return if @access_token && @token_expires_at && Time.current < @token_expires_at

    token_url = TOKEN_URL_TEMPLATE % @tenant_id

    response = HTTParty.post(token_url, {
      body: {
        client_id: @client_id,
        client_secret: @client_secret,
        scope: SCOPE,
        grant_type: "client_credentials"
      },
      headers: { "Content-Type" => "application/x-www-form-urlencoded" }
    })

    if response.success?
      @access_token = response.parsed_response["access_token"]
      expires_in = response.parsed_response["expires_in"] || 3600
      @token_expires_at = Time.current + expires_in.to_i.seconds - 60.seconds # refresh 1 min early
    else
      error_desc = response.parsed_response&.dig("error_description") || response.body
      raise "Microsoft Graph authentication failed: #{error_desc}"
    end
  end

  def parse_email(msg)
    from = msg.dig("from", "emailAddress") || {}

    {
      message_id: msg["id"],
      subject: msg["subject"],
      sender_email: from["address"],
      sender_name: from["name"],
      body_text: strip_html(msg.dig("body", "content") || ""),
      body_html: msg.dig("body", "content"),
      received_at: msg["receivedDateTime"],
      conversation_id: msg["conversationId"],
      has_attachments: msg["hasAttachments"]
    }
  end

  def strip_html(html)
    # Basic HTML to text conversion
    text = html.gsub(/<br\s*\/?>|<\/p>|<\/div>|<\/li>/i, "\n")
    text = text.gsub(/<[^>]+>/, "")
    text = text.gsub(/&nbsp;/i, " ")
    text = text.gsub(/&amp;/i, "&")
    text = text.gsub(/&lt;/i, "<")
    text = text.gsub(/&gt;/i, ">")
    text = text.gsub(/&#39;|&apos;/i, "'")
    text = text.gsub(/&quot;/i, '"')
    text.strip.gsub(/\n{3,}/, "\n\n")
  end

  def graph_get(path, query: {})
    HTTParty.get(
      "#{GRAPH_BASE_URL}#{path}",
      query: query,
      headers: auth_headers
    )
  end

  def graph_post(path, body:)
    HTTParty.post(
      "#{GRAPH_BASE_URL}#{path}",
      body: body,
      headers: auth_headers.merge("Content-Type" => "application/json")
    )
  end

  def graph_patch(path, body:)
    HTTParty.patch(
      "#{GRAPH_BASE_URL}#{path}",
      body: body,
      headers: auth_headers.merge("Content-Type" => "application/json")
    )
  end

  def auth_headers
    { "Authorization" => "Bearer #{@access_token}" }
  end
end
