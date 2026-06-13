class MockPropertyService
  def self.search(query)
    seed = deterministic_seed(query.to_s)
    rng = Random.new(seed)
    count = rng.rand(1..5)
    count.times.map do |i|
      s = Random.new(seed + i)
      {
        id: "PROP-#{s.rand(10000..99999)}",
        address: generate_address(s),
        match_score: (0.7 + s.rand * 0.3).round(2)
      }
    end.tap { |r| Rails.logger.info("[MockPropertyService] search(#{query}) returned #{r.size} results") }
  end

  def self.get_valuation(property_id_or_address)
    seed = deterministic_seed(property_id_or_address.to_s)
    rng = Random.new(seed)
    estimate = (rng.rand(400_000..3_000_000) / 1000) * 1000
    variance = (estimate * 0.1).to_i
    growth = (2.0 + rng.rand * 8.0).round(1)
    {
      estimate: estimate, low: estimate - variance, high: estimate + variance,
      confidence: %w[High Medium Low][rng.rand(3)],
      methodology: "Comparable sales analysis",
      comparable_sales: 3.times.map { |i| s = Random.new(seed + 100 + i); { address: generate_address(s), sale_price: estimate + s.rand(-variance..variance), sale_date: Date.current - s.rand(30..365) } },
      market_trend: %w[growing stable declining][rng.rand(3)],
      annual_growth_rate: growth,
      risk_rating: %w[low medium high][rng.rand(3)],
      valuation_date: Date.current
    }.tap { |r| Rails.logger.info("[MockPropertyService] get_valuation(#{property_id_or_address}) estimate=#{r[:estimate]}") }
  end

  def self.get_details(property_id_or_address)
    seed = deterministic_seed(property_id_or_address.to_s)
    rng = Random.new(seed)
    {
      bedrooms: rng.rand(1..6), bathrooms: rng.rand(1..4), car_spaces: rng.rand(0..3),
      land_area: rng.rand(200..2000), floor_area: rng.rand(80..500),
      property_type: %w[House Apartment Townhouse Unit][rng.rand(4)],
      year_built: rng.rand(1950..2023),
      zoning: %w[Residential Commercial Mixed][rng.rand(3)],
      flood_risk: %w[none low medium high][rng.rand(4)],
      bushfire_risk: %w[none low medium high][rng.rand(4)],
      council: [ "Brisbane City Council", "Gold Coast City Council", "Sydney City Council", "Melbourne City Council" ][rng.rand(4)],
      images: 3.times.map { |i| "https://mock-images.example.com/property/#{seed}/#{i}.jpg" }
    }.tap { |r| Rails.logger.info("[MockPropertyService] get_details(#{property_id_or_address}) type=#{r[:property_type]}") }
  end

  def self.get_risk_assessment(property_id_or_address)
    seed = deterministic_seed(property_id_or_address.to_s)
    rng = Random.new(seed)
    levels = %w[none low medium high]
    factors = { flood: levels[rng.rand(4)], bushfire: levels[rng.rand(4)], subsidence: levels[rng.rand(3)], contamination: levels[rng.rand(3)] }
    worst = %w[none low medium high]
    overall = factors.values.map { |v| worst.index(v) }.max
    {
      overall_risk: worst[overall],
      factors: factors,
      insurance_estimate_annual: (1200 + rng.rand(0..3000) / 100 * 100),
      notes: "Automated risk assessment based on property location and characteristics."
    }.tap { |r| Rails.logger.info("[MockPropertyService] get_risk_assessment(#{property_id_or_address}) risk=#{r[:overall_risk]}") }
  end

  private

  def self.deterministic_seed(input)
    Digest::MD5.hexdigest(input)[0..7].to_i(16)
  end

  def self.generate_address(rng)
    streets = [ "Smith St", "Queen St", "George St", "Park Ave", "Main Rd", "High St", "Victoria Dr", "Albert St" ]
    suburbs = [ "Brisbane", "Paddington", "Newstead", "Woolloongabba", "Fortitude Valley", "South Bank", "West End", "Kangaroo Point" ]
    "#{rng.rand(1..200)} #{streets[rng.rand(streets.size)]}, #{suburbs[rng.rand(suburbs.size)]}"
  end
end
