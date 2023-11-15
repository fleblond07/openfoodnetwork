# frozen_string_literal: true

class EnterpriseBuilder < DfcBuilder
  def self.enterprise(enterprise)
    variants = enterprise.supplied_variants.to_a
    catalog_items = variants.map(&method(:catalog_item))
    supplied_products = catalog_items.map(&:product)
    address = AddressBuilder.address(enterprise.address)

    DataFoodConsortium::Connector::Enterprise.new(
      urls.enterprise_url(enterprise.id),
      name: enterprise.name,
      description: enterprise.description,
      vatNumber: enterprise.abn,
      suppliedProducts: supplied_products,
      catalogItems: catalog_items,
      emails: [enterprise.email_address].compact,
      localizations: [address],
      phoneNumbers: [enterprise.phone].compact,
      socialMedias: SocialMediaBuilder.social_medias(enterprise),
      websites: [enterprise.website].compact,
    ).tap do |e|
      e.registerSemanticProperty("ofn:long_description") do
        enterprise.long_description
      end
      e.registerSemanticProperty("ofn:contact_name") do
        # This could be expressed as dfc-b:hasMainContact Person with name.
        # But that would require a new endpoint for a single string.
        enterprise.contact_name
      end
      e.registerSemanticProperty("ofn:logo_url") do
        enterprise.logo.url
      end
    end
  end

  def self.enterprise_group(group)
    members = group.enterprises.map do |member|
      urls.enterprise_url(member.id)
    end

    DataFoodConsortium::Connector::Enterprise.new(
      urls.enterprise_group_url(group.id),
      name: group.name,
      description: group.description,
    ).tap do |enterprise|
      # This property has been agreed by the DFC but hasn't made it's way into
      # the Connector yet.
      enterprise.registerSemanticProperty("dfc-b:affiliatedBy") do
        members
      end
    end
  end
end
