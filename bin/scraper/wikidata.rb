#!/bin/env ruby
# frozen_string_literal: true

require_relative '../../lib/wikidata_query'

query = <<SPARQL
  SELECT ?id ?name ?group ?district WHERE {
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

puts WikidataQuery.new(query, 'every-politican-scrapers/finland-eduskunta').csv
