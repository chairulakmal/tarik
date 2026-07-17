# Dedupes Stripe webhook deliveries — Stripe retries events, and processing
# checkout.session.completed twice would destroy and recreate the subscription.
class ProcessedStripeEvent < ApplicationRecord
  # Returns false if the event was already recorded (i.e. a duplicate delivery).
  def self.record(event_id)
    create!(event_id: event_id)
    true
  rescue ActiveRecord::RecordNotUnique
    false
  end
end
