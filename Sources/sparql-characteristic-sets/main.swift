//
//  main.swift
//  Kineo
//
//  Created by Gregory Todd Williams on 6/24/16.
//  Copyright © 2016 Gregory Todd Williams. All rights reserved.
//

import Foundation
import SPARQLSyntax
import SPARQLQueryAnalysis

@discardableResult
func extractCharacteristicSets(from sparql : String) throws -> [CharacteristicSet] {
    guard var p = SPARQLParser(string: sparql) else { fatalError("Failed to construct SPARQL parser") }
    let a = try p.parseAlgebra()
    let sets = try characteristicSets(from: a)
    return sets
}

var seenSets = Set<[String]>()
let a = QueryAnalysis()
let results = try a.forEachQuery { (lineno, sparql, flags, args) -> Int in
    do {
        let sets = try extractCharacteristicSets(from: sparql)
        for cs in sets {
            let preds = cs.predicates.map { $0.value }.sorted()
            seenSets.insert(preds)
        }
    } catch {
        print("ERROR:\(lineno): Failed to process query: \(error)")
        print("FAILED:\(lineno): \(sparql)")
    }
    return 0
}

for cs in seenSets {
    print(cs)
}
