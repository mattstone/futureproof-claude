class BrokerDashboardCacheService
  # Request-level cache for broker dashboard metrics
  # Caches within a single request to avoid duplicate DB queries
  # Cache TTL: 1 hour (expires after one request completes)

  CACHE_TTL = 1.hour
  CACHE_NAMESPACE = "broker_dashboard"

  def self.fetch_stats(broker)
    cache_key = "#{CACHE_NAMESPACE}:stats:#{broker.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      calculate_stats(broker)
    end
  end

  def self.fetch_applications(broker, page: 1, per_page: 20)
    cache_key = "#{CACHE_NAMESPACE}:applications:#{broker.id}:#{page}:#{per_page}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      ::Application.by_broker(broker)
                    .where(lender_id: broker.lenders.ids)
                    .includes(:user, :lender, :distributions)
                    .order(created_at: :desc)
                    .page(page)
                    .per(per_page)
    end
  end

  def self.fetch_application_detail(application)
    cache_key = "#{CACHE_NAMESPACE}:application:#{application.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      {
        applicant: application.user,
        distributions: application.distributions.order(created_at: :desc)
      }
    end
  end

  def self.invalidate_stats(broker)
    cache_key = "#{CACHE_NAMESPACE}:stats:#{broker.id}"
    Rails.cache.delete(cache_key)
  end

  def self.invalidate_applications(broker)
    # Invalidate all pagination variants
    (1..10).each do |page|
      [10, 20, 50].each do |per_page|
        cache_key = "#{CACHE_NAMESPACE}:applications:#{broker.id}:#{page}:#{per_page}"
        Rails.cache.delete(cache_key)
      end
    end
  end

  def self.invalidate_application_detail(application)
    cache_key = "#{CACHE_NAMESPACE}:application:#{application.id}"
    Rails.cache.delete(cache_key)
  end

  def self.invalidate_broker_cache(broker)
    invalidate_stats(broker)
    invalidate_applications(broker)
  end

  private

  def self.calculate_stats(broker)
    lender_ids = broker.lenders.ids
    applications = ::Application.by_broker(broker).where(lender_id: lender_ids)

    {
      total: applications.count,
      pending: applications.where(status: [ :submitted, :processing ]).count,
      approved: applications.where(status: :accepted).count,
      rejected: applications.where(status: :rejected).count
    }
  end
end
