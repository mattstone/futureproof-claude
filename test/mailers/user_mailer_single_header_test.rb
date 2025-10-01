require "test_helper"

class UserMailerSingleHeaderTest < ActionMailer::TestCase
  test "verification email has only one header" do
    user = users(:admin_user)
    user.verification_code = "123456"
    user.verification_code_expires_at = 1.hour.from_now
    
    email = UserMailer.verification_code(user)

    # Check that the email body contains only ONE instance of "Futureproof"
    # in the header context (the main title, not in content)
    body_html = email.html_part ? email.html_part.body.to_s : email.body.to_s
    
    # Should have the tagline
    assert body_html.include?("Your Financial Future, Secured"), 
      "Email should include the tagline 'Your Financial Future, Secured'"
    
    # Check that we don't have duplicate headers - should have branding in header and maybe footer
    # but not multiple header sections
    assert body_html.scan(/<h1[^>]*>.*?Futureproof.*?<\/h1>/mi).length <= 1,
      "Should have at most one H1 header with Futureproof branding"
      
    # The word "Futureproof" should appear in header (once) and possibly in content
    # but we shouldn't see duplicate header structures
    assert body_html.include?("Futureproof"), "Should have Futureproof branding"
  end
  
  test "security notification email has only one header" do
    user = users(:admin_user)
    
    email = UserMailer.security_notification(
      user,
      "test-signature",
      "Chrome on macOS",
      "127.0.0.1",
      "Sydney, Australia"
    )

    body_html = email.html_part ? email.html_part.body.to_s : email.body.to_s
    
    # Should have the tagline
    assert body_html.include?("Your Financial Future, Secured"), 
      "Email should include the tagline"
      
    # Should only have one main branding header
    header_patterns = body_html.scan(/<h1[^>]*>.*?Futureproof.*?<\/h1>/m)
    assert header_patterns.length <= 1, 
      "Should have at most one H1 header with Futureproof branding"
  end
end
