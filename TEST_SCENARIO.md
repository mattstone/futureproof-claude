# Customer Application Journey - Complete Test Scenario

## Overview

This document outlines the complete customer journey from homepage to fully uploaded application, with all documents received and verified.

## Test Scenario: "John Doe" Complete EPM Application

### Prerequisites

- Lender account created and configured
- Mortgage product available (EPM model)
- Test user credentials ready

---

## Step-by-Step Manual Test Flow

### **Step 1: Borrower Account Creation**
- Go to: Homepage → "Get Started" / "Apply Now"
- **Action:** Create new account
- **Input:**
  - Email: john.doe@example.com
  - Password: TestPass123!
  - First Name: John
  - Last Name: Doe
  - Country: Australia
- **Expected:**
  - Account created
  - Confirmation email sent
  - Redirected to application form

---

### **Step 2: Application Creation & Property Details**

**Application Status:** `created` → `property_details`

- Go to: Dashboard → "Start Application"
- **Action:** Fill property details form
- **Input:**
  - Property Address: 123 Main Street, Sydney NSW 2000
  - Property Value: $750,000
  - Ownership Status: Individual
  - Property Type: Primary Residence
  - Existing Mortgage: No
- **Expected:**
  - Form validates successfully
  - Status advances to `property_details`
  - Form auto-saves

---

### **Step 3: Income & Loan Selection**

**Application Status:** `property_details` → `income_and_loan_options`

- Go to: Application → "Income & Loan Details"
- **Action:** Select mortgage product and enter loan details
- **Input:**
  - Mortgage Product: "EPM Standard" (1.5% guaranteed income)
  - Loan Amount: $300,000 (40% LTV)
  - Loan Term: 20 years
  - Monthly Income Required: $4,500
  - Borrower Age: 65
  - Growth Rate: 6% p.a.
- **Expected:**
  - Mortgage calculator shows:
    - Monthly Income: $4,500
    - LTV Ratio: 40%
    - Repayment: $0 (no monthly repayments)
  - Form validates successfully
  - Status advances to `income_and_loan_options`

---

### **Step 4: Application Review & Submission**

**Application Status:** `income_and_loan_options` → `submitted`

- Go to: Application → "Summary"
- **Action:** Review all details and submit
- **Display:**
  - All entered information summarized
  - Loan calculations confirmed
  - Key Facts Sheet preview
- **Submission:**
  - Click "Submit Application"
  - Confirmation message shown
  - Status changes to `submitted`
- **Expected:**
  - Application submitted successfully
  - Lender notified (email)
  - Automatic document requirement list created:
    - [ ] Identity (Passport/Driver's License)
    - [ ] Income Proof (Tax Return/Bank Statements)
    - [ ] Bank Statement (Recent 3 months)
    - [ ] Property Title

---

### **Step 5: Lender Review & Approval**

**Application Status:** `submitted` → `processing` → `accepted`

- **Admin/Lender Access:** (Separate from borrower)
- Go to: Lender Dashboard → Applications → John Doe's Application
- **Review:**
  - Verify application details
  - Check property valuation
  - Confirm loan calculations
  - Review borrower information
- **Approval:**
  - Click "Approve Application"
  - Set approved loan amount: $300,000
  - Set approved interest rate: 3.5%
  - Set approved term: 20 years
  - Click "Confirm Approval"
- **Expected:**
  - Status changes to `accepted`
  - Automatic documents generated:
    - ✓ Mortgage Contract (PDF)
    - ✓ Key Facts Sheet (PDF)
    - ✓ Income Statements (PDF)
  - Documents queued for delivery to borrower
  - Lender dashboard shows: "Application Approved"

---

### **Step 6: Borrower Portal Access & Document Viewing**

**Portal:** Borrower Portal (`/au/borrower_portal/:application_id`)

- Go to: Email link in "Application Approved" notification
- **Or manually:** Dashboard → Applications → View Portal
- **Portal shows:**
  - Application Status: "Approved - Pending Documents"
  - Property Details (read-only)
  - Loan Details (read-only)
  - **Documents Section:**
    - Mortgage Contract (Download)
    - Key Facts Sheet (Download)
    - Income Statements (Download)
  - **Required Documents Checklist:**
    - [ ] Identity Document - Status: Pending Upload
    - [ ] Income Proof - Status: Pending Upload
    - [ ] Bank Statement - Status: Pending Upload
    - [ ] Property Title - Status: Pending Upload
- **Expected:**
  - All pages load successfully
  - Documents available for download
  - Download links work (PDF files generated)
  - Borrower can read all information

---

### **Step 7: Borrower Downloads Documents**

- Go to: Borrower Portal → Documents
- **Action:** Download each document
  1. Click "Download Mortgage Contract" → Saves PDF
  2. Click "Download Key Facts Sheet" → Saves PDF
  3. Click "Download Income Statements" → Saves PDF
- **Expected:**
  - All PDF files download successfully
  - Files are readable and contain correct information
  - No errors or broken links
  - File sizes are reasonable (> 100KB)

---

### **Step 8: Borrower Uploads Required Documents**

**Application Status:** `accepted` (no change)

- Go to: Borrower Portal → Documents → "Upload Required Documents"
- **Upload Process:**
  - Click "Choose File" for "Identity Document"
  - Select scanned passport/driver's license image (JPG/PDF)
  - Repeat for:
    - Income Proof (Tax Return or Bank Statement)
    - Bank Statement (Recent 3-month statement)
    - Property Title (Title search or deed)
- **Expected:**
  - All files upload successfully
  - Progress indicator shows upload status
  - Files appear in checklist as "Uploaded"
  - Confirmation message shown
  - Email notification sent to lender

---

### **Step 9: Admin/Lender Verifies Documents**

**Admin Panel:** Lender Dashboard → Applications → Documents

- Go to: Lender Dashboard → John Doe's Application → Documents tab
- **Verification Process:**
  - For each uploaded document:
    1. View document preview (thumbnail)
    2. Click "Verify"
    3. Add verification notes: "Document verified - matches identity"
    4. Click "Confirm Verification"
  - Document status changes: Uploaded → Verified
- **Documents to Verify:**
  1. Identity Document
  2. Income Proof
  3. Bank Statement
  4. Property Title
- **Expected:**
  - All documents marked as "Verified"
  - Timestamps recorded
  - Verified by: Admin name
  - Notes saved

---

### **Step 10: Loan Activation**

**Application Status:** `accepted` → `activated`

**Admin/Lender Action:**

- Go to: Lender Dashboard → John Doe's Application
- **Activation:**
  - Click "Activate Loan"
  - Review final loan details
  - Click "Confirm Activation"
  - Status changes to `activated`
- **System Action (automatic):**
  - Create initial Distribution record
  - Queue first payment ($4,500 monthly income)
  - Send "Loan Activated" email to borrower
  - Generate payment receipt

- **Expected:**
  - Status: `activated`
  - First distribution created
  - Email confirmation sent
  - Borrower portal updates to show: "Loan Active"

---

### **Step 11: Borrower Verifies Activation & First Payment**

**Borrower Portal:**

- Go to: Borrower Portal → Dashboard
- **Expected to see:**
  - Application Status: "Active"
  - Next Payment: $4,500 on [date 30 days from activation]
  - Payment History section shows:
    - Payment 1: $4,500 - Completed - [date] - Receipt [link]
  - Messages section shows:
    - System message: "Your loan has been activated. First payment will be deposited on [date]."
  - Key Documents:
    - Mortgage Contract (Signed)
    - Key Facts Sheet
    - Income Payment Schedule
- **Download:**
  - Payment Receipt (PDF)
  - Income Payment Schedule (PDF)

---

### **Step 12: Final Verification - "Fully Uploaded"**

**Definition:** Application is "fully uploaded" when:

✅ All required documents uploaded  
✅ All documents verified  
✅ Application status is `activated`  
✅ Borrower has received all documents  
✅ First payment is processed  

**Verification Checklist:**

```
Application Status:
  ✓ Status = "Activated"
  ✓ Lender assigned
  ✓ Loan amount: $300,000

Documents:
  ✓ Mortgage Contract (System-generated, verified)
  ✓ Key Facts Sheet (System-generated, verified)
  ✓ Income Statements (System-generated, verified)
  ✓ Identity Document (Borrower-uploaded, verified)
  ✓ Income Proof (Borrower-uploaded, verified)
  ✓ Bank Statement (Borrower-uploaded, verified)
  ✓ Property Title (Borrower-uploaded, verified)
  
Total Documents: 7
Verified: 7/7 (100%)

Distributions:
  ✓ Distribution 1: $4,500 (Completed)
  ✓ Next: [Month 2 amount and date]

Borrower Portal:
  ✓ All pages accessible
  ✓ All documents downloadable
  ✓ Payment history visible
  ✓ Next payment date shown
```

---

## Success Criteria

The test is **PASSED** when:

1. ✅ Application created with all required details
2. ✅ Status progresses: created → property_details → income_and_loan_options → submitted → processing → accepted → activated
3. ✅ All 7 required documents present in system
4. ✅ All documents verified by admin
5. ✅ First monthly payment ($4,500) processed successfully
6. ✅ Borrower can download all documents
7. ✅ Borrower can view payment schedule
8. ✅ No errors in borrower portal
9. ✅ All notifications/emails sent correctly
10. ✅ Application marked as "activated" with no outstanding items

---

## Failure Points to Watch

❌ Application submission validation errors  
❌ Documents not generating/not visible to borrower  
❌ Download links broken or return wrong files  
❌ Document upload fails  
❌ Admin verification interface errors  
❌ Loan activation fails  
❌ First payment not created  
❌ Borrower portal not accessible  
❌ Email notifications not sent  

---

## Automated Test Code

See: `test/integration/customer_application_journey_test.rb`

This file includes a complete RSpec integration test that:
- Creates borrower account
- Submits application with all details
- Triggers lender approval
- Generates documents
- Simulates document verification
- Activates application
- Verifies final state

**To run:**
```bash
bin/rails test test/integration/customer_application_journey_test.rb
```

**Expected output:**
```
✓ Step 1: Borrower account created
✓ Step 2: Application created
✓ Step 3: Property details filled
✓ Step 4: Income & loan details filled
✓ Step 5: Application submitted
✓ Step 6: Application approved by lender
✓ Step 7: Documents generated
✓ Step 8: Borrower can view documents
✓ Step 9: Borrower downloads documents
✓ Step 10: Required documents uploaded
✓ Step 11: Documents verified
✓ Step 12: Application activated
✓ Step 13: Final verification - Application fully uploaded

✅ FULL CUSTOMER JOURNEY COMPLETE
```

---

## Time Estimate

**Manual Test:** 30-45 minutes per run  
**Automated Test:** 2-3 seconds
