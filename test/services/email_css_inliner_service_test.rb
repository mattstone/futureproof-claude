require 'test_helper'

class EmailCssInlinerServiceTest < ActiveSupport::TestCase
  test "inlines simple CSS class to style attribute" do
    html = '<table class="email-table"><tr><td class="email-header-cell">Content</td></tr></table>'
    result = EmailCssInlinerService.inline_css(html)
    
    assert_includes result, 'style="width: 100%; border-collapse: collapse; border: 0; border-spacing: 0;"'
    assert_includes result, 'style="text-align: center;"'
    refute_includes result, 'class="email-table"'
    refute_includes result, 'class="email-header-cell"'
  end

  test "handles multiple classes on same element" do
    html = '<div class="email-content-text email-strong">Hello</div>'
    result = EmailCssInlinerService.inline_css(html)
    
    # Should contain both style properties merged
    assert_includes result, 'margin: 0 0 24px 0'
    assert_includes result, 'color: #1f2937'
  end

  test "preserves content and structure" do
    html = '<p class="email-greeting">Hello <%= @user.name %></p>'
    result = EmailCssInlinerService.inline_css(html)
    
    assert_includes result, 'Hello <%= @user.name %>'
    assert_includes result, '<p'
    assert_includes result, '</p>'
  end

  test "handles HTML without CSS classes" do
    html = '<div>Plain content</div>'
    result = EmailCssInlinerService.inline_css(html)
    
    assert_equal html, result
  end

  test "processes email button styles correctly" do
    html = '<td class="email-button-cell"><a class="email-button-link" href="#">Button</a></td>'
    result = EmailCssInlinerService.inline_css(html)
    
    assert_includes result, 'background: linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)'
    assert_includes result, 'display: inline-block'
    assert_includes result, 'padding: 16px 32px'
  end
end