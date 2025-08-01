module BrowserFingerprintHelper
  def generate_browser_signature(request)
    user_agent = request.user_agent || ""
    accept_language = request.headers['Accept-Language'] || ""
    accept_encoding = request.headers['Accept-Encoding'] || ""
    
    # Create a signature from stable browser characteristics
    signature_data = [
      user_agent,
      accept_language,
      accept_encoding,
      request.headers['Sec-Ch-Ua'] || "",
      request.headers['Sec-Ch-Ua-Platform'] || ""
    ].join('|')
    
    # Generate a hash from the signature data
    Digest::SHA256.hexdigest(signature_data)[0, 32]
  end

  def extract_browser_info(request)
    user_agent = request.user_agent || ""
    
    # Parse basic browser information
    browser_info = {
      user_agent: user_agent,
      browser: parse_browser_name(user_agent),
      platform: parse_platform(user_agent),
      language: request.headers['Accept-Language']&.split(',')&.first || "Unknown"
    }

    browser_info
  end

  private

  def parse_browser_name(user_agent)
    case user_agent
    when /Chrome/i
      if user_agent.include?('Edg/')
        "Microsoft Edge"
      elsif user_agent.include?('OPR/')
        "Opera"
      else
        "Google Chrome"
      end
    when /Firefox/i
      "Mozilla Firefox"
    when /Safari/i
      user_agent.include?('Chrome') ? "Google Chrome" : "Safari"
    when /Opera/i
      "Opera"
    else
      "Unknown Browser"
    end
  end

  def parse_platform(user_agent)
    case user_agent
    when /Windows/i
      "Windows"
    when /Macintosh|Mac OS X/i
      "macOS"
    when /Linux/i
      "Linux"
    when /iPhone|iPad/i
      "iOS"
    when /Android/i
      "Android"
    else
      "Unknown Platform"
    end
  end
end