# frozen_string_literal: true

# Finds wholesale offers for retail products.
class FdcOfferBroker
  # TODO: Find a better way to provide this data.
  Solution = Struct.new(:product, :factor, :offer)
  RetailSolution = Struct.new(:retail_product_id, :factor)

  def self.load_catalog(user, urls)
    api = DfcRequest.new(user)
    catalog_json = api.call(urls.catalog_url)
    DfcIo.import(catalog_json)
  end

  def initialize(user, urls)
    @user = user
    @urls = urls
  end

  def catalog
    @catalog ||= self.class.load_catalog(@user, @urls)
  end

  def best_offer(product_id)
    Solution.new(
      wholesale_product(product_id),
      contained_quantity(product_id),
      offer_of(wholesale_product(product_id))
    )
  end

  def wholesale_product(product_id)
    production_flow = catalog_item("#{product_id}/AsPlannedProductionFlow")

    if production_flow
      production_flow.product
    else
      # We didn't find a wholesale variant, falling back to the given product.
      catalog_item(product_id)
    end
  end

  def contained_quantity(product_id)
    consumption_flow = catalog_item("#{product_id}/AsPlannedConsumptionFlow")

    # If we don't find a transformation, we return the original product,
    # which contains exactly one of itself (identity).
    consumption_flow&.quantity&.value&.to_i || 1
  end

  def wholesale_to_retail(wholesale_product_id)
    production_flow = flow_producing(wholesale_product_id)

    return RetailSolution.new(wholesale_product_id, 1) if production_flow.nil?

    consumption_flow = catalog_item(
      production_flow.semanticId.sub("AsPlannedProductionFlow", "AsPlannedConsumptionFlow")
    )
    retail_product_id = consumption_flow.product.semanticId

    contained_quantity = consumption_flow.quantity.value.to_i

    RetailSolution.new(retail_product_id, contained_quantity)
  end

  def offer_of(product)
    product&.catalogItems&.first&.offers&.first&.tap do |offer|
      # Unfortunately, the imported catalog doesn't provide the reverse link:
      offer.offeredItem = product
    end
  end

  def catalog_item(id)
    @catalog_by_id ||= catalog.index_by(&:semanticId)
    @catalog_by_id[id]
  end

  def flow_producing(wholesale_product_id)
    @production_flows_by_product_id ||= production_flows.index_by { |flow| flow.product.semanticId }
    @production_flows_by_product_id[wholesale_product_id]
  end

  def production_flows
    @production_flows ||= catalog.select do |i|
      i.semanticType == "dfc-b:AsPlannedProductionFlow"
    end
  end
end
