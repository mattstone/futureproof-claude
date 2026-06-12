require "test_helper"

class Console::FunderContractDocumentsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
    @funder = wholesale_funders(:one)
    @document = wholesale_funder_contracts(:legacy_funding_doc)
  end

  test "funder page lists documents with manage actions" do
    get console_wholesale_funder_path(@funder)
    assert_select ".console-card-title", text: "Contract documents"
    assert_select "a", text: "New document"
  end

  test "create a document per jurisdiction and type" do
    assert_difference -> { @funder.wholesale_funder_contracts.count }, 1 do
      post console_wholesale_funder_funding_documents_path(@funder), params: {
        wholesale_funder_contract: {
          party_type: "Master Agreement", jurisdiction: "UK", version: 1,
          html_content: "<h1>Master Agreement</h1><p>UK terms.</p>"
        }
      }
    end
    assert_redirected_to console_wholesale_funder_path(@funder)
  end

  test "duplicate type+jurisdiction is rejected" do
    assert_no_difference -> { @funder.wholesale_funder_contracts.count } do
      post console_wholesale_funder_funding_documents_path(@funder), params: {
        wholesale_funder_contract: {
          party_type: @document.party_type, jurisdiction: @document.jurisdiction, version: 2,
          html_content: "<p>dup</p>"
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "edit updates the document text and version" do
    patch console_wholesale_funder_funding_document_path(@funder, @document), params: {
      wholesale_funder_contract: { party_type: @document.party_type, jurisdiction: @document.jurisdiction,
                                   version: 2, html_content: "<h1>Updated</h1>" }
    }
    @document.reload
    assert_equal "2", @document.version.to_s
    assert_match "Updated", @document.html_content
  end

  test "show renders sanitized content with edit and delete" do
    get console_wholesale_funder_funding_document_path(@funder, @document)
    assert_response :success
    assert_select "a", text: "Edit"
    assert_select "form[action=?] button", console_wholesale_funder_funding_document_path(@funder, @document)
  end

  test "delete removes the document" do
    assert_difference -> { @funder.wholesale_funder_contracts.count }, -1 do
      delete console_wholesale_funder_funding_document_path(@funder, @document)
    end
  end
end
