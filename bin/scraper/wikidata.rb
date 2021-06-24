#!/bin/env ruby
# frozen_string_literal: true

require 'cgi'
require 'csv'
require 'scraped'

class Results < Scraped::JSON
  field :members do
    json[:results][:bindings].map { |result| fragment(result => Member).to_h }
  end
end

class Member < Scraped::JSON
  field :id do
    json.dig(:id, :value)
  end

  field :name do
    json.dig(:name, :value)
  end

  field :group do
    json.dig(:group, :value)
  end

  field :district do
    json.dig(:district, :value)
  end
end

# In this case it might make more sense to fetch as CSV and output it
# directly, but this way keeps it in sync with our normal approach, and
# allows us to more easily post-process if needed
WIKIDATA_SPARQL_URL = 'https://query.wikidata.org/sparql?format=json&query=%s'

memberships_query = <<SPARQL
  SELECT ?id ?item ?name ?group ?district WHERE {
    # Current members of the 38th Parliament of Finland
    ?item p:P39 ?ps .
    ?ps ps:P39 wd:Q17592486 ; pq:P2937 wd:Q47459902 .
    FILTER NOT EXISTS { ?ps pq:P582 [] }
    OPTIONAL {
      ?ps pq:P4100 ?groupItem .
      OPTIONAL { ?groupItem rdfs:label ?group FILTER(LANG(?group) = "en") }
    }
    OPTIONAL {
      ?ps pq:P768 ?districtItem .
      OPTIONAL { ?districtItem rdfs:label ?district FILTER(LANG(?district) = "en") }
    }

    # An Eduskunta ID, and optional "named as"
    OPTIONAL {
      ?item p:P2181 ?idstatement .
      ?idstatement ps:P2181 ?id .
      OPTIONAL { ?idstatement pq:P1810 ?eduskuntaName }
    }

    # Their on-wiki label as a fall-back if no Eduskunta name
    OPTIONAL { ?item rdfs:label ?fiLabel FILTER(LANG(?fiLabel) = "fi") }
    BIND(COALESCE(?eduskuntaName, ?fiLabel) AS ?name)
  }
  ORDER BY ?name
SPARQL

url = WIKIDATA_SPARQL_URL % CGI.escape(memberships_query)
headers = { 'User-Agent' => 'every-politican-scrapers/finland-eduskunta' }
data = Results.new(response: Scraped::Request.new(url: url, headers: headers).response).members

header = data.first.keys.to_csv
rows = data.map { |row| row.values.to_csv }
abort 'No results' if rows.count.zero?

puts header + rows.join
