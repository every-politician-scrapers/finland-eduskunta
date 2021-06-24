#!/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'scraped'

# require 'pry'
# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'

class Legislature
  # details for an individual member
  class Member < Scraped::HTML
    field :id do
      File.basename(url, '.*')
    end

    field :name do
      tds[0].text.tidy
    end

    field :group do
      tds[5].text.tidy
    end

    field :district do
      district_heading[/Electoral District of ([^(]+)/, 1].tidy
    end

    private

    def tds
      noko.css('td')
    end

    def url
      tds[3].text.tidy
    end

    def district_heading
      # There's probably a better way to find this, but going via ancestor is slow and awkward
      # //ancestor::div[contains(concat(' ',normalize-space(@class),' '),' s4-wpcell-plain ')][.//h2]
      noko.parent.parent.parent.parent.parent.css('h2').text.tidy
    end
  end

  # The page listing all the members
  class Members < Scraped::HTML
    field :members do
      # noko.xpath("//ancestor::div[contains(concat(' ',normalize-space(@class),' '),' s4-wpcell-plain ')][.//h2]")
      noko.xpath('.//table/tr').map { |mp| fragment(mp => Member).to_h }
    end
  end
end

url = 'https://www.eduskunta.fi/EN/kansanedustajat/nykyiset_kansanedustajat/Pages/default.aspx'
data = Legislature::Members.new(response: Scraped::Request.new(url: url).response).members

header = data.first.keys.to_csv
rows = data.map { |row| row.values.to_csv }
abort 'No results' if rows.count.zero?

puts header + rows.join
