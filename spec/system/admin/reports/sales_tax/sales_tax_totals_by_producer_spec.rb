# frozen_string_literal: true

require 'system_helper'

RSpec.describe "Sales Tax Totals By Producer" do
  #  Scenario 1: added tax
  #  1 producer
  #  1 distributor
  #  1 product that costs 100$
  #  1 order with 1 line item
  #  the line item match 2 tax rates: country (2.5%) and state (1.5%)
  let!(:table_header){
    [
      "Distributor",
      "Distributor Tax Status",
      "Producer",
      "Producer Tax Status",
      "Order Cycle",
      "Tax Category",
      "Tax Rate Name",
      "Tax Rate",
      "Total excl. tax ($)",
      "Tax",
      "Total incl. tax ($)"
    ].join(" ")
  }
  let!(:state_zone){ create(:zone_with_state_member) }
  let!(:country_zone) { create(:zone_with_member) }
  let!(:tax_category) { create(:tax_category, name: 'tax_category') }
  let!(:state_tax_rate) {
    create(:tax_rate, name: 'State', amount: 0.015, zone: state_zone, tax_category:)
  }
  let!(:country_tax_rate) {
    create(:tax_rate, name: 'Country', amount: 0.025, zone: country_zone, tax_category:)
  }
  let!(:ship_address) { create(:ship_address) }
  let(:another_state){ create(:state, name: 'Another state', country: ship_address.country) }

  let!(:variant) { create(:variant, supplier:, tax_category:) }
  let!(:product) { variant.product }
  let!(:supplier) { create(:supplier_enterprise, name: 'Supplier', charges_sales_tax: true) }
  let!(:distributor) { create(:distributor_enterprise_with_tax, name: 'Distributor') }
  let!(:payment_method) { create(:payment_method, :flat_rate) }
  let!(:shipping_method) { create(:shipping_method, :flat_rate) }

  let!(:order) { create(:order_with_distributor, distributor:) }
  let!(:order_cycle) {
    create(:simple_order_cycle, name: 'oc1', suppliers: [supplier], distributors: [distributor],
                                variants: [variant])
  }

  let(:admin) { create(:admin_user) }

  before do
    distributor.shipping_methods << shipping_method
    distributor.payment_methods << payment_method
  end

  context 'added tax' do
    before do
      order.line_items.create({ variant:, quantity: 1, price: 100 })
      order.update!({
                      order_cycle_id: order_cycle.id,
                      ship_address_id: ship_address.id
                    })

      Orders::WorkflowService.new(order).complete!
    end

    it "generates the report" do
      login_as admin
      visit admin_reports_path
      click_on 'Sales Tax Totals By Producer'

      run_report
      expect(page.find("table.report__table thead tr").text).to have_content(table_header)

      expect(page.find("table.report__table tbody").text).to have_content([
        "Distributor",
        "Yes",
        "Supplier",
        "Yes",
        "oc1",
        "tax_category",
        "State",
        "1.5 %",
        "100.0",
        "1.5",
        "101.5"
      ].join(" "))

      expect(page.find("table.report__table tbody").text).to have_content([
        "Distributor",
        "Yes",
        "Supplier",
        "Yes",
        "oc1",
        "tax_category",
        "Country",
        "2.5 %",
        "100.0",
        "2.5",
        "102.5"
      ].join(" "))

      expect(page.find("table.report__table tbody").text).to have_content([
        "TOTAL",
        "100.0",
        "4.0",
        "104.0"
      ].join(" "))
    end
  end

  context 'Order not to be shipped in a state affected by state tax rate' do
    # Therefore, do not apply both tax rates here, only country one
    before do
      ship_address.update!({ state_id: another_state.id })
      order.line_items.create({ variant:, quantity: 1, price: 100 })
      order.update!({
                      order_cycle_id: order_cycle.id,
                      ship_address_id: ship_address.id
                    })

      Orders::WorkflowService.new(order).complete!
    end

    it 'generates the report' do
      login_as admin
      visit admin_reports_path
      click_on 'Sales Tax Totals By Producer'

      run_report
      expect(page.find("table.report__table thead tr").text).to have_content(table_header)

      expect(page.find("table.report__table tbody").text).to have_content([
        "Distributor",
        "Yes",
        "Supplier",
        "Yes",
        "oc1",
        "tax_category",
        "Country",
        "2.5 %",
        "100.0",
        "2.5",
        "102.5"
      ].join(" "))

      expect(page.find("table.report__table tbody").text).to have_content([
        "TOTAL",
        "100.0",
        "2.5",
        "102.5"
      ].join(" "))

      # Even though 2 tax rates exist (but only one has been applied), we should get only 2 lines:
      # one line item + total
      expect(page.all("table.report__table tbody tr").count).to eq(2)
    end
  end

  context 'included tax' do
    before do
      state_tax_rate.update!({ included_in_price: true })
      country_tax_rate.update!({ included_in_price: true })

      order.line_items.create({ variant:, quantity: 1, price: 100 })
      order.update!({
                      order_cycle_id: order_cycle.id,
                      ship_address_id: ship_address.id
                    })

      Orders::WorkflowService.new(order).complete!
    end
    it "generates the report" do
      login_as admin
      visit admin_reports_path
      click_on 'Sales Tax Totals By Producer'

      run_report
      expect(page.find("table.report__table thead tr").text).to have_content(table_header)

      expect(page.find("table.report__table tbody").text).to have_content([
        "Distributor",
        "Yes",
        "Supplier",
        "Yes",
        "oc1",
        "tax_category",
        "State",
        "1.5 %",
        "96.08",
        "1.48",
        "97.56"
      ].join(" "))

      expect(page.find("table.report__table tbody").text).to have_content([
        "Distributor",
        "Yes",
        "Supplier",
        "Yes",
        "oc1",
        "tax_category",
        "Country",
        "2.5 %",
        "96.08",
        "2.44",
        "98.52"
      ].join(" "))

      expect(page.find("table.report__table tbody").text).to have_content([
        "TOTAL",
        "96.08",
        "3.92",
        "100.0"
      ].join(" "))
    end
  end

  context 'should filter by customer' do
    let!(:order2){ create(:order_with_distributor, distributor:) }
    let!(:customer1){ create(:customer, enterprise: create(:enterprise), user: create(:user)) }
    let!(:customer2){ create(:customer, enterprise: create(:enterprise), user: create(:user)) }
    let!(:customer_email_dropdown_selector){ "#s2id_q_customer_id_in" }
    let!(:country_tax_rate_row){
      [
        "Distributor",
        "Yes",
        "Supplier",
        "Yes",
        "oc1",
        "tax_category",
        "Country",
        "2.5 %",
        "300.0",
        "7.5",
        "307.5"
      ].join(" ")
    }
    let!(:state_tax_rate_row){
      [
        "Distributor",
        "Yes",
        "Supplier",
        "Yes",
        "oc1",
        "tax_category",
        "State",
        "1.5 %",
        "300.0",
        "4.5",
        "304.5"
      ].join(" ")
    }
    let(:summary_row){
      [
        "TOTAL",
        "300.0",
        "12.0",
        "312.0"
      ].join(" ")
    }

    let(:customer1_country_tax_rate_row){
      [
        "Distributor",
        "Yes",
        "Supplier",
        "Yes",
        "oc1",
        "tax_category",
        "Country",
        "2.5 %",
        "100.0",
        "2.5",
        "102.5"
      ].join(" ")
    }
    let(:customer1_state_tax_rate_row){
      [
        "Distributor",
        "Yes",
        "Supplier",
        "Yes",
        "oc1",
        "tax_category",
        "State",
        "1.5 %",
        "100.0",
        "1.5",
        "101.5"
      ].join(" ")
    }
    let(:customer1_summary_row){
      [
        "TOTAL",
        "100.0",
        "4.0",
        "104.0"
      ].join(" ")
    }

    let(:customer2_country_tax_rate_row){
      [
        "Distributor",
        "Yes",
        "Supplier",
        "Yes",
        "oc1",
        "tax_category",
        "Country",
        "2.5 %",
        "200.0",
        "5.0",
        "205.0"
      ].join(" ")
    }
    let(:customer2_state_tax_rate_row){
      [
        "Distributor",
        "Yes",
        "Supplier",
        "Yes",
        "oc1",
        "tax_category",
        "State",
        "1.5 %",
        "200.0",
        "3.0",
        "203.0"
      ].join(" ")
    }
    let(:customer2_summary_row){
      [
        "TOTAL",
        "200.0",
        "8.0",
        "208.0"
      ].join(" ")
    }

    before do
      order.line_items.create({ variant:, quantity: 1, price: 100 })
      order.update!({
                      order_cycle_id: order_cycle.id,
                      ship_address_id: customer1.bill_address_id,
                      customer_id: customer1.id
                    })
      Orders::WorkflowService.new(order).complete!

      order2.line_items.create({ variant:, quantity: 1, price: 200 })
      order2.update!({
                       order_cycle_id: order_cycle.id,
                       ship_address_id: customer2.bill_address_id,
                       customer_id: customer2.id
                     })
      Orders::WorkflowService.new(order2).complete!
      login_as admin
      visit admin_reports_path
      click_on 'Sales Tax Totals By Producer'
    end

    it "should load all the orders" do
      run_report

      expect(page.find("table.report__table thead tr").text).to have_content(table_header)
      expect(page.find("table.report__table tbody").text).to have_content(state_tax_rate_row)
      expect(page.find("table.report__table tbody").text).to have_content(country_tax_rate_row)
      expect(page.find("table.report__table tbody").text).to have_content(summary_row)
    end

    it "should filter customer1 orders" do
      page.find(customer_email_dropdown_selector).click
      find('li', text: customer1.email).click

      run_report

      expect(page.find("table.report__table thead tr").text).to have_content(table_header)
      expect(
        page.find("table.report__table tbody").text
      ).to have_content(customer1_country_tax_rate_row)
      expect(
        page.find("table.report__table tbody").text
      ).to have_content(customer1_state_tax_rate_row)
      expect(page.find("table.report__table tbody").text).to have_content(customer1_summary_row)
    end

    it "should filter customer2 orders" do
      page.find(customer_email_dropdown_selector).click
      find('li', text: customer2.email).click

      run_report

      expect(page.find("table.report__table thead tr").text).to have_content(table_header)
      expect(
        page.find("table.report__table tbody").text
      ).to have_content(customer2_country_tax_rate_row)
      expect(
        page.find("table.report__table tbody").text
      ).to have_content(customer2_state_tax_rate_row)
      expect(page.find("table.report__table tbody").text).to have_content(customer2_summary_row)
    end

    it "should filter customer1 and customer2 orders" do
      page.find(customer_email_dropdown_selector).click
      find('li', text: customer1.email).click
      page.find(customer_email_dropdown_selector).click
      find('li', text: customer2.email).click
      run_report

      expect(page.find("table.report__table thead tr").text).to have_content(table_header)
      expect(page.find("table.report__table tbody").text).to have_content(state_tax_rate_row)
      expect(page.find("table.report__table tbody").text).to have_content(country_tax_rate_row)
      expect(page.find("table.report__table tbody").text).to have_content(summary_row)
    end
  end
end
