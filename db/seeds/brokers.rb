# Create test brokers for development
if Rails.env.development?
  # Create test brokers
  broker1 = Broker.find_or_create_by(email: 'broker1@example.com') do |b|
    b.name = 'Broker Alpha'
    b.phone = '02 1234 5678'
    b.password = 'BrokerPass123!'
    b.password_confirmation = 'BrokerPass123!'
    b.active = true
  end

  broker2 = Broker.find_or_create_by(email: 'broker2@example.com') do |b|
    b.name = 'Broker Beta'
    b.phone = '02 9876 5432'
    b.password = 'BrokerPass123!'
    b.password_confirmation = 'BrokerPass123!'
    b.active = true
  end

  if broker1.persisted? && broker2.persisted?
    puts "✅ Test brokers created: #{broker1.name}, #{broker2.name}"
  else
    puts "⚠️  Some brokers already existed or failed"
  end

  # Assign brokers to a lender if it exists
  if Lender.any?
    lender = Lender.first
    BrokerLender.find_or_create_by(broker_id: broker1.id, lender_id: lender.id) do |bl|
      bl.active = true
    end
    BrokerLender.find_or_create_by(broker_id: broker2.id, lender_id: lender.id) do |bl|
      bl.active = true
    end
    puts "✅ Brokers assigned to lender: #{lender.name}"
  else
    puts "⚠️  No lenders found to assign brokers"
  end
end
