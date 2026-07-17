class CreateProcessedStripeEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :processed_stripe_events do |t|
      t.string :event_id, null: false
      t.datetime :created_at, null: false
    end
    add_index :processed_stripe_events, :event_id, unique: true
  end
end
