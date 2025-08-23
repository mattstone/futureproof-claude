# Fix MIME type for JavaScript modules to prevent browser errors
class JavaScriptMimeTypeFixer
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)
    
    # Fix MIME type for JavaScript files to support ES6 modules
    if (headers['content-type'] == 'text/javascript' || headers['content-type'] == 'text/plain') && 
       (env['PATH_INFO'].end_with?('.js') || env['PATH_INFO'].include?('/assets/') && env['PATH_INFO'].match?(/\.(js|mjs)$/))
      headers['content-type'] = 'application/javascript'
    end
    
    [status, headers, response]
  end
end

Rails.application.config.middleware.use JavaScriptMimeTypeFixer