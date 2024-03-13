# frozen_string_literal: true

class WeightsAndMeasures
  def initialize(variant)
    @variant = variant
    @units = UNITS
  end

  def scale_for_unit_value
    largest_unit = find_largest_unit(scales_for_variant_unit, system)
    return [nil, nil] unless largest_unit

    [largest_unit[0], largest_unit[1]["name"]]
  end

  def system
    return "custom" unless scales = scales_for_variant_unit(ignore_available_units: true)
    return "custom" unless product_scale = @variant.product.variant_unit_scale

    scales[product_scale.to_f]['system']
  end

  # @returns enumerable with label and value for select
  def self.variant_unit_options
    available_units_sorted.flat_map do |measurement, measurement_info|
      measurement_info.filter_map do |scale, unit_info|
        scale_clean =
          ActiveSupport::NumberHelper.number_to_rounded(scale, precision: nil,
                                                               strip_insignificant_zeros: true)
        [
          "#{I18n.t(measurement)} (#{unit_info['name']})", # Label (eg "Weight (g)")
          "#{measurement}_#{scale_clean}", # Scale ID (eg "weight_1")
        ]
      end
    end <<
      [
        I18n.t('items'),
        'items'
      ]
  end

  def self.available_units
    Spree::Config.available_units.split(",")
  end

  def self.available_units_sorted
    self::UNITS.transform_values do |measurement_info|
      measurement_info.filter do |_scale, unit_info|
        available_units.include?(unit_info['name'])
      end.sort.to_h # sort by unit (hash key)
    end
  end

  private

  UNITS = {
    'weight' => {
      0.001 => { 'name' => 'mg', 'system' => 'metric' },
      1.0 => { 'name' => 'g', 'system' => 'metric' },
      1000.0 => { 'name' => 'kg', 'system' => 'metric' },
      1_000_000.0 => { 'name' => 'T', 'system' => 'metric' },

      28.349523125 => { 'name' => 'oz', 'system' => 'imperial' },
      28.35 => { 'name' => 'oz', 'system' => 'imperial' },
      453.59237 => { 'name' => 'lb', 'system' => 'imperial' },
      453.6 => { 'name' => 'lb', 'system' => 'imperial' },
    },
    'volume' => {
      0.001 => { 'name' => 'mL', 'system' => 'metric' },
      0.01 => { 'name' => 'cL', 'system' => 'metric' },
      0.1 => { 'name' => 'dL', 'system' => 'metric' },
      1.0 => { 'name' => 'L', 'system' => 'metric' },
      1000.0 => { 'name' => 'kL', 'system' => 'metric' },

      4.54609 => { 'name' => 'gal', 'system' => 'imperial' },
    }
  }.freeze

  def scales_for_variant_unit(ignore_available_units: false)
    return @units[@variant.product.variant_unit] if ignore_available_units

    @units[@variant.product.variant_unit]&.reject { |_scale, unit_info|
      self.class.available_units.exclude?(unit_info['name'])
    }
  end

  # Find the largest available and compatible unit where unit_value comes
  #   to >= 1 when expressed in it.
  # If there is none available where this is true, use the smallest available unit.
  def find_largest_unit(scales, product_scale_system)
    return nil unless scales

    largest_unit = scales.select { |scale, unit_info|
      unit_info['system'] == product_scale_system &&
        @variant.unit_value / scale >= 1
    }.max
    return scales.first if largest_unit.nil?

    largest_unit
  end
end
