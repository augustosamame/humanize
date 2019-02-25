require 'bigdecimal'
require_relative './humanize/locales'

module Humanize
  # Big numbers are big: http://wiki.answers.com/Q/What_number_is_after_vigintillion&src=ansTT

  def humanize(locale: Humanize.config.default_locale,
               decimals_as: Humanize.config.decimals_as,
               cents: false)
    locale_class = Humanize.for_locale(locale)

    return locale_class::SUB_ONE_GROUPING[0] if zero?

    infinity = to_f.infinite?
    if infinity
      infinity_word = locale_class::INFINITY
      return infinity == 1 ? infinity_word : "#{locale_class::NEGATIVE} #{infinity_word}"
    elsif is_a?(Float) && nan?
      return locale_class::UNDEFINED
    end

    sign = locale_class::NEGATIVE if negative?

    parts = locale_class.new.humanize(abs)
    process_decimals(locale_class, locale, parts, decimals_as)
    Humanize.stringify(parts, sign, cents)
  end

  def self.for_locale(locale)
    case locale.to_sym
    # NOTE: add locales here in ealphabetical order
    when :az
      Humanize::Az
    when :de
      Humanize::De
    when :en
      Humanize::En
    when :fr
      Humanize::Fr
    when :id
      Humanize::Id
    when :ru
      Humanize::Ru
    when :th
      Humanize::Th
    when :tr
      Humanize::Tr
    else
      raise "Unsupported humanize locale: #{locale}"
    end
  end

  def self.stringify(parts, sign, cents = false)
    unless cents
      found_index = parts.find_index { |x| x == "and" }
      if found_index
        parts[found_index] = Humanize.dollarize(parts[-1])
      else
        parts[0] += parts[0] == "one" ? ' dollar and zero cents' : ' dollars and zero cents'
      end
    end
    output = parts.reverse.join(' ').squeeze(' ')
    if sign
      "#{sign} #{output} #{'cents' if cents}"
    else
      "#{output} #{'cents' if cents}"
    end
  end

  def self.dollarize(output)
    output == "one" ? 'dollar and' : 'dollars and'
  end

  def process_decimals(locale_class, locale, parts, decimals_as)
    return unless is_a?(Float) || is_a?(BigDecimal)

    # Why 15?
    # (byebug) BigDecimal.new(number, 15)
    # 0.8000015e1
    # (byebug) BigDecimal.new(number, 16)
    # 0.8000014999999999e1
    decimal = BigDecimal(self, 15) - BigDecimal(to_i)

    _sign, significant_digits, _base, exponent = decimal.split
    return if significant_digits == "0"

    grouping = locale_class::SUB_ONE_GROUPING
    leading_zeroes = [grouping[0]] * exponent.abs
    decimals_as = :digits if leading_zeroes.any?

    decimals_as_words = case decimals_as
                        when :digits
                          significant_digits.to_i.humanize(locale: locale, cents: true)
                        when :number
                          significant_digits.to_i.humanize(locale: locale)
                        when :cents
                          if significant_digits.to_i < 10
                            (significant_digits.to_i * 10).humanize(locale: locale, cents: true)
                          else
                            significant_digits.to_i.humanize(locale: locale, cents: true)
                          end
                        end

    parts.insert(0, decimals_as_words, locale_class::POINT)
  end

  def self.decimals_as_number(decimal, locale:)
    decimal.significant_digits.join('').to_i.humanize(locale: locale)
  end

  class << self
    attr_writer :config
  end

  def self.config
    @config ||= Configuration.new
  end

  def self.reset_config
    @config = Configuration.new
  end

  def self.configure
    yield(config)
  end

  class Configuration
    attr_accessor :default_locale, :decimals_as

    def initialize
      @default_locale = :en
      @decimals_as = :cents
    end
  end
end

class Integer
  include Humanize
end

class Float
  include Humanize
end

class BigDecimal
  include Humanize
end
