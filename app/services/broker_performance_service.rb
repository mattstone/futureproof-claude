class BrokerPerformanceService
  def initialize(lender:, broker: nil)
    @lender = lender
    @broker = broker
  end

  # Get all brokers for a lender with their performance metrics
  def all_broker_metrics
    @lender.brokers.active.map { |broker| broker_metrics(broker) }
  end

  # Get metrics for a specific broker
  def broker_metrics(broker)
    applications = broker_applications(broker)
    approved = applications.where(status: :accepted)
    
    {
      broker_id: broker.id,
      broker_name: broker.name,
      broker_email: broker.email,
      applications_sourced: applications.count,
      approved_count: approved.count,
      conversion_rate: conversion_rate(applications.count, approved.count),
      total_loan_value: approved.sum(:approved_loan_amount).to_f,
      average_deal_size: average_deal_size(approved),
      active: broker.active
    }
  end

  # Broker sourced applications for lender
  def broker_applications(broker)
    Application.where(broker_id: broker.id, lender_id: @lender.id)
  end

  # Applications with broker attribution
  def applications_with_brokers
    @lender.applications.includes(:broker).order(created_at: :desc)
  end

  # Applications filtered by broker (if @broker is set)
  def filtered_applications
    apps = applications_with_brokers
    apps = apps.where(broker_id: @broker.id) if @broker
    apps
  end

  # Top performing brokers (by conversion rate)
  def top_brokers(limit: 5)
    all_broker_metrics.sort_by { |m| m[:conversion_rate] }.reverse.take(limit)
  end

  # Brokers needing attention (low conversion rate)
  def underperforming_brokers(threshold: 0.15)
    all_broker_metrics.select { |m| m[:conversion_rate] < threshold && m[:applications_sourced] > 5 }
  end

  private

  def conversion_rate(total, approved)
    return 0.0 if total.zero?
    (approved.to_f / total * 100).round(1)
  end

  def average_deal_size(approved_applications)
    return 0.0 if approved_applications.empty?
    (approved_applications.sum(:approved_loan_amount).to_f / approved_applications.count).round(2)
  end
end
