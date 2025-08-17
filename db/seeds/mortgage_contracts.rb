# Create sample Equity Preservation Mortgage Contract
unless MortgageContract.exists?
  puts "Creating sample Equity Preservation Mortgage Contract..."
  
  MortgageContract.create!(
    title: "Equity Preservation Mortgage Contract",
    content: <<~MARKUP,
      ## 1. Loan Agreement Details
      
      This Equity Preservation Mortgage Agreement ("Agreement") is entered into between:
      
      **Lender:** Futureproof Financial Group Limited
      **Borrower:** [Borrower Name]
      **Property:** [Property Address]
      **Loan Amount:** [Loan Amount]
      **Loan-to-Value Ratio:** [LVR]%
      **Interest Rate:** [Interest Rate]% per annum
      **Loan Term:** [Loan Term] years
      
      ## 2. Equity Preservation Features
      
      ### 2.1 Equity Protection
      
      This mortgage includes innovative equity preservation features designed to protect your home's value:
      
      - **Market Value Protection:** Your loan amount will not exceed the original LVR even if property values decline
      - **Equity Sharing:** You maintain full ownership and benefit from any property value increases
      - **No Negative Equity:** You will never owe more than your property is worth at the time of sale
      - **Capital Growth Participation:** Benefit from 100% of capital growth above the original purchase price
      
      ### 2.2 Interest Rate Structure
      
      - **Initial Rate:** [Interest Rate]% per annum
      - **Rate Type:** [Fixed/Variable/Split]
      - **Rate Review:** Annual review based on market conditions
      - **Interest Only Period:** [IO Period] years (if applicable)
      
      ## 3. Repayment Terms
      
      ### 3.1 Monthly Payments
      
      - **Payment Amount:** $[Monthly Payment] per month
      - **Payment Date:** [Day] of each month
      - **Payment Method:** Direct debit from nominated account
      - **Payment Frequency:** Monthly (other frequencies available on request)
      
      ### 3.2 Principal and Interest Calculation
      
      Your monthly payments are calculated based on:
      - Principal reduction over the loan term
      - Interest charges on the outstanding balance
      - Any applicable fees and charges
      
      ### 3.3 Early Repayment
      
      You may repay this loan early without penalty, subject to:
      - 30 days written notice to the lender
      - Settlement of outstanding balance including accrued interest
      - Discharge of security and registration fees
      
      ## 4. Security and Insurance
      
      ### 4.1 Property Security
      
      This loan is secured by a first mortgage over the property described above. The security provides:
      - Legal protection for the lender's interest
      - Clear title verification
      - Priority over other creditors
      
      ### 4.2 Insurance Requirements
      
      You must maintain the following insurance coverage:
      - **Building Insurance:** Full replacement value coverage
      - **Public Liability:** Minimum $20 million coverage
      - **Mortgage Protection:** Optional but recommended for income protection
      - **Contents Insurance:** Recommended for personal belongings
      
      ## 5. Borrower Obligations
      
      ### 5.1 Property Maintenance
      
      You agree to:
      - Maintain the property in good repair and condition
      - Obtain consent before making structural alterations
      - Comply with all local council and government regulations
      - Allow reasonable inspections by the lender (with notice)
      
      ### 5.2 Financial Obligations
      
      You must:
      - Make all payments on time as specified
      - Maintain adequate insurance coverage
      - Pay all rates, taxes, and utility charges
      - Notify us of any financial difficulties promptly
      
      ## 6. Default and Enforcement
      
      ### 6.1 Events of Default
      
      Default occurs if you:
      - Fail to make required payments for 30+ days
      - Breach any material covenant in this agreement
      - Become insolvent, bankrupt, or enter administration
      - Sell or transfer the property without consent
      
      ### 6.2 Remedies
      
      Upon default, we may (subject to applicable laws):
      - Demand immediate repayment of the outstanding balance
      - Exercise powers of sale over the secured property
      - Appoint a receiver to manage the property
      - Pursue legal action for recovery of amounts owed
      
      ## 7. Fees and Charges
      
      ### 7.1 Establishment Fees
      
      **Application Fee:** $[Amount] (covers credit assessment and processing)
      **Valuation Fee:** $[Amount] (professional property valuation)
      **Legal Fees:** $[Amount] (mortgage documentation and registration)
      **Settlement Fee:** $[Amount] (settlement administration)
      
      ### 7.2 Ongoing Fees
      
      **Monthly Service Fee:** $[Amount] (account maintenance and administration)
      **Annual Review Fee:** $[Amount] (annual rate and LVR review)
      **Discharge Fee:** $[Amount] (when loan is fully repaid)
      
      ### 7.3 Additional Charges
      
      The following may apply in specific circumstances:
      - Late payment fee: $[Amount] per occurrence
      - Default administration fee: $[Amount] per month
      - Property inspection fee: $[Amount] per inspection
      - Variation fee: $[Amount] for loan modifications
      
      ## 8. Regulatory Information
      
      ### 8.1 Credit Provider Details
      
      **Credit Provider:** Futureproof Financial Group Limited
      **Australian Credit Licence:** [ACL Number]
      **ABN:** [ABN Number]
      **Registered Office:** [Office Address]
      **Contact Email:** legal@futureprooffinancial.app
      **Phone:** 1300 XXX XXX
      
      ### 8.2 Consumer Protection
      
      This loan is regulated under the National Consumer Credit Protection Act 2009. You have certain rights including:
      - The right to receive clear loan documentation
      - Protection against unfair contract terms
      - Access to external dispute resolution
      - Hardship assistance if you experience financial difficulties
      
      ### 8.3 Dispute Resolution
      
      If you have a complaint or dispute:
      1. **Internal Resolution:** Contact us directly at complaints@futureprooffinancial.app
      2. **External Resolution:** If unresolved after 45 days, contact:
         - Australian Financial Complaints Authority (AFCA)
         - Website: www.afca.org.au
         - Phone: 1800 931 678
         - Email: info@afca.org.au
      
      ## 9. Variation and Assignment
      
      ### 9.1 Loan Variations
      
      This agreement may be varied by mutual consent in writing. Common variations include:
      - Interest rate adjustments (subject to terms)
      - Payment frequency changes
      - Loan term extensions or reductions
      - Additional borrowing (subject to serviceability)
      
      ### 9.2 Assignment Rights
      
      We may assign our rights under this agreement to another lender or financial institution. You will be notified of any assignment in advance.
      
      ## 10. Agreement Terms
      
      ### 10.1 Governing Law
      
      This agreement is governed by the laws of [State/Territory] and the Commonwealth of Australia. Any disputes will be resolved in the courts of [State/Territory].
      
      ### 10.2 Entire Agreement
      
      This agreement, together with any loan schedule and security documents, constitutes the entire agreement between the parties and supersedes all prior negotiations, representations, and agreements.
      
      ### 10.3 Severability
      
      If any provision of this agreement is found to be invalid or unenforceable, the remaining provisions will continue in full force and effect.
      
      ## 11. Special Conditions
      
      ### 11.1 Equity Preservation Guarantee
      
      Subject to the terms of this agreement, we guarantee that:
      - Your equity position will be preserved relative to market movements
      - You will not be liable for any shortfall on sale due to market decline
      - Capital growth above original purchase price remains 100% with you
      
      ### 11.2 Professional Advice
      
      We recommend that you:
      - Seek independent legal advice before signing
      - Consider independent financial advice regarding your circumstances
      - Understand all terms and conditions before proceeding
      - Keep copies of all documentation for your records
      
      **Contact Information:**
      Lender: Futureproof Financial Group Limited
      Email: legal@futureprooffinancial.app
      Phone: 1300 XXX XXX
      Address: [Lender Address]
      Website: www.futureprooffinancial.app
    MARKUP
    last_updated: Time.current,
    is_active: false,
    is_draft: true,
    version: 1
  )
  
  puts "Sample mortgage contract created successfully!"
else
  puts "Mortgage contracts already exist, skipping sample creation."
end