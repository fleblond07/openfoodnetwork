# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Api::Admin::ProductSerializer do
  let(:product) { create(:simple_product, supplier_id: create(:supplier_enterprise).id) }
  let(:serializer) { described_class.new(product) }

  it "serializes a product" do
    expect(serializer.to_json).to match(product.name)
  end
end
