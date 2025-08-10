# Rack Attack configuration for rate limiting and DDoS protection
class Rack::Attack
  
  # Always allow local requests
  safelist('allow from localhost') do |req|
    ['127.0.0.1', '::1'].include? req.ip
  end
  
  # Block suspicious requests (attempts to access sensitive files)
  blocklist('block suspicious requests') do |req|
    # Block requests for sensitive files
    req.path =~ %r{/\.env} ||
    req.path =~ %r{/\.git} ||
    req.path =~ %r{/config/database\.yml} ||
    req.path =~ %r{/config/secrets\.yml} ||
    req.path =~ %r{/admin} && req.get? && req.path =~ %r{\.php$} ||
    req.path =~ %r{wp-admin} ||
    req.path =~ %r{xmlrpc\.php}
  end
  
  # Block requests with malicious User-Agents
  blocklist('block bad user agents') do |req|
    req.user_agent =~ %r{nikto|nmap|masscan|sqlmap|dirb|gobuster|curl/bot}i
  end
  
  # Throttle POST requests to sensitive endpoints
  throttle('sensitive posts', limit: 3, period: 1.minute) do |req|
    if req.post? && req.path.match?(%r{^/(users|admin)})
      req.ip
    end
  end
  
  # Throttle login attempts
  throttle('login attempts', limit: 5, period: 10.minutes) do |req|
    if req.path == '/users/sign_in' && req.post?
      req.ip
    end
  end
  
  # Throttle registration attempts
  throttle('registration attempts', limit: 3, period: 1.hour) do |req|
    if req.path == '/users' && req.post?
      req.ip
    end
  end
  
  # Throttle password reset requests
  throttle('password resets', limit: 2, period: 1.hour) do |req|
    if req.path == '/users/password' && req.post?
      req.ip
    end
  end
  
  # Throttle API requests
  throttle('api requests', limit: 100, period: 1.hour) do |req|
    if req.path.start_with?('/api/')
      req.ip
    end
  end
  
  # Throttle admin actions more strictly
  throttle('admin actions', limit: 50, period: 1.hour) do |req|
    if req.path.start_with?('/admin/') && (req.post? || req.put? || req.patch? || req.delete?)
      req.ip
    end
  end
  
  # General request throttling
  throttle('general requests', limit: 300, period: 1.hour) do |req|
    req.ip
  end
  
  # Exponential backoff for repeat offenders
  throttle('repeat offenders', limit: 10, period: 1.day) do |req|
    req.ip if Rack::Attack::Allow2Ban.filter(req.ip, maxretry: 20, findtime: 1.hour, bantime: 1.day) { false }
  end
  
  # Custom response for throttled requests
  self.throttled_responder = lambda do |req|
    retry_after = req.env['rack.attack.match_data'][:period] rescue 60
    [
      429,
      {
        'Content-Type' => 'text/plain',
        'Retry-After' => retry_after.to_s,
        'X-RateLimit-Limit' => req.env['rack.attack.match_data'][:limit].to_s,
        'X-RateLimit-Remaining' => '0',
        'X-RateLimit-Reset' => (Time.now + retry_after).iso8601
      },
      ['Rate limit exceeded. Please try again later.']
    ]
  end
  
  # Custom response for blocked requests
  self.blocklisted_responder = lambda do |req|
    [403, {'Content-Type' => 'text/plain'}, ['Forbidden']]
  end
end

# Enable logging
ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, payload|
  req = payload[:request]
  case req.env['rack.attack.match_type']
  when :throttle, :blocklist
    Rails.logger.warn "[Rack::Attack] #{req.env['rack.attack.match_type'].to_s.upcase} #{req.env['rack.attack.matched']}: #{req.ip} #{req.request_method} #{req.fullpath}"
  when :safelist
    Rails.logger.info "[Rack::Attack] SAFELIST #{req.env['rack.attack.matched']}: #{req.ip} #{req.request_method} #{req.fullpath}"
  end
end