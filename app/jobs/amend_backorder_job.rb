# frozen_string_literal: true

# When orders are created, adjusted or cancelled, we need to amend
# an existing backorder as well.
class AmendBackorderJob < ApplicationJob
  sidekiq_options retry: 0

  def self.schedule_bulk_update_for(orders)
    # We can have one backorder per order cycle and distributor.
    groups = orders.group_by { |order| [order.order_cycle, order.distributor] }
    groups.each_value do |orders_with_same_backorder|
      # We need to trigger only one update per backorder.
      perform_later(orders_with_same_backorder.first)
    end
  end

  def perform(order)
    OrderLocker.lock_order_and_variants(order) do
      amend_backorder(order)
    end
  end

  def amend_backorder(order)
    backorder = BackorderUpdater.new.amend_backorder(order)

    user = order.distributor.owner
    urls = nil # Not needed to send order. The backorder id is the URL.
    FdcBackorderer.new(user, urls).send_order(backorder) if backorder
  end
end
