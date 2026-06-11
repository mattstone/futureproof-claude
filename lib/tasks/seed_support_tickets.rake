namespace :support do
  desc "Seed sample support tickets for development"
  task seed: :environment do
    puts "Seeding support tickets..."

    # Find an existing user if possible
    existing_user = User.where(admin: false).first

    tickets_data = [
      {
        subject: "How does the EPM annuity work?",
        sender_email: "john.smith@gmail.com",
        sender_name: "John Smith",
        status: "open",
        priority: "normal",
        category: "general",
        source: "email",
        messages: [
          { sender_type: "customer", body_text: "Hi, I've been looking at your website and I'm interested in the Equity Preservation Mortgage. Could you explain how the annuity payments work? I own a home worth about $650,000 in Sydney and I'm wondering what kind of monthly income I could expect. Thanks, John" }
        ]
      },
      {
        subject: "Application status update",
        sender_email: existing_user&.email || "mary.jones@outlook.com",
        sender_name: existing_user&.display_name || "Mary Jones",
        user: existing_user,
        status: "in_progress",
        priority: "normal",
        category: "application",
        source: "email",
        messages: [
          { sender_type: "customer", body_text: "Hello, I submitted my EPM application about two weeks ago and haven't heard back yet. Could you give me an update on where things are at? My property is in Melbourne. Thanks, Mary" },
          { sender_type: "agent", body_text: "Hi Mary, thank you for your patience. I can see your application is currently in the property valuation stage. The valuer has been scheduled for this Thursday. You should receive a notification once that's complete. Please let me know if you have any other questions.", sender_name: "Matt Stone", sender_email: "matt.stone@futureprooffinancial.co" }
        ]
      },
      {
        subject: "Payment not received this month",
        sender_email: "david.chen@yahoo.com",
        sender_name: "David Chen",
        status: "open",
        priority: "urgent",
        category: "payment",
        source: "email",
        messages: [
          { sender_type: "customer", body_text: "I normally receive my EPM annuity payment on the 1st of each month but it's now the 5th and nothing has come through. This is the first time this has happened. Can you please look into this urgently? My account is with Westpac, BSB 032-000." }
        ]
      },
      {
        subject: "EPM available for investment property?",
        sender_email: "sarah.williams@protonmail.com",
        sender_name: "Sarah Williams",
        status: "waiting_on_customer",
        priority: "low",
        category: "general",
        source: "email",
        messages: [
          { sender_type: "customer", body_text: "I have a rental property in Auckland worth about NZ$850,000. Is the EPM available for investment properties or only owner-occupied homes?" },
          { sender_type: "agent", body_text: "Hi Sarah, great question. The EPM is primarily designed for owner-occupied residential properties. Investment properties may be considered on a case-by-case basis depending on the property type and jurisdiction. Could you tell me a bit more about the property — is it a standalone house or an apartment? And is it currently tenanted?", sender_name: "Matt Stone", sender_email: "matt.stone@futureprooffinancial.co" }
        ]
      },
      {
        subject: "Formal complaint about valuation",
        sender_email: "robert.taylor@gmail.com",
        sender_name: "Robert Taylor",
        status: "open",
        priority: "high",
        category: "complaint",
        source: "email",
        messages: [
          { sender_type: "customer", body_text: "I am writing to make a formal complaint. The property valuation that was done for my EPM application came in at $480,000 but comparable sales in my street have been over $550,000. I believe the valuation is significantly below market value and I want it reviewed. If this isn't resolved satisfactorily I will be taking the matter further." }
        ]
      },
      {
        subject: "Can I cancel during cooling-off period?",
        sender_email: "emma.brown@icloud.com",
        sender_name: "Emma Brown",
        status: "resolved",
        priority: "normal",
        category: "general",
        source: "email",
        resolved_at: 2.days.ago,
        messages: [
          { sender_type: "customer", body_text: "I signed my EPM contract last week but I've had a change of circumstances. Am I still within the cooling-off period and can I cancel without any penalties?" },
          { sender_type: "agent", body_text: "Hi Emma, yes — in Australia you have a 14-day cooling-off period after signing the contract, during which you can cancel without penalty. Based on your signing date, you still have 7 days remaining. To cancel, simply reply to this email confirming you wish to withdraw. Is there anything else I can help with?", sender_name: "Matt Stone", sender_email: "matt.stone@futureprooffinancial.co" },
          { sender_type: "customer", body_text: "Thank you for the quick response. I've decided to go ahead with the EPM after all — my circumstances have changed again! No need to cancel." },
          { sender_type: "agent", body_text: "Great to hear, Emma! Your application will continue as normal. Don't hesitate to reach out if you have any other questions.", sender_name: "Matt Stone", sender_email: "matt.stone@futureprooffinancial.co" }
        ]
      },
      {
        subject: "Technical issue with calculator",
        sender_email: "tech.savvy@gmail.com",
        sender_name: "Alex Kumar",
        status: "closed",
        priority: "low",
        category: "technical",
        source: "email",
        resolved_at: 5.days.ago,
        closed_at: 4.days.ago,
        messages: [
          { sender_type: "customer", body_text: "The calculator on your website seems to be returning $0 for the monthly annuity when I enter a property value of $1,200,000 with a 25-year term. Is this a bug?" },
          { sender_type: "agent", body_text: "Hi Alex, thanks for reporting this. I've checked and it appears the calculator was having an issue with values over $1M in the NZ region. Our dev team has deployed a fix. Could you try again and let me know if it works now?", sender_name: "Matt Stone", sender_email: "matt.stone@futureprooffinancial.co" },
          { sender_type: "customer", body_text: "Working perfectly now, thanks!" }
        ]
      }
    ]

    tickets_data.each do |data|
      messages = data.delete(:messages)
      user = data.delete(:user)

      # Create ticket with a temporary ticket_number (will be set by after_create)
      ticket = SupportTicket.new(data.merge(ticket_number: "TEMP-#{SecureRandom.hex(4)}"))
      ticket.user = user if user
      ticket.save!

      messages.each_with_index do |msg_data, i|
        ticket.messages.create!(
          sender_type: msg_data[:sender_type],
          sender_name: msg_data[:sender_name] || data[:sender_name],
          sender_email: msg_data[:sender_email] || data[:sender_email],
          body_text: msg_data[:body_text],
          created_at: ticket.created_at + (i * 2).hours
        )
      end

      puts "  Created ticket #{ticket.ticket_number}: #{ticket.subject} (#{ticket.status})"
    end

    puts "Done! Created #{SupportTicket.count} support tickets."
  end
end
