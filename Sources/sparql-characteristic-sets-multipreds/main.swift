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
func analyzeCharacteristicSets(from sparql : String) throws -> (Int, Int) {
    guard var p = SPARQLParser(string: sparql) else { fatalError("Failed to construct SPARQL parser") }
    let a = try p.parseAlgebra()
    let sets = try characteristicSets(from: a)
    let multi = sets.filter{ $0.hasMultiple }.count
    if multi > 0 {
        print("Uses multiple predicates:")
        print(sparql)
    }
    return (multi, sets.count)
}

let a = QueryAnalysis()
let results = try a.forEachQuery { (lineno, sparql, flags, args) -> (Int, Int) in
    do {
        let count = try analyzeCharacteristicSets(from: sparql)
        return count
    } catch {
        print("ERROR:\(lineno): Failed to process query: \(error)")
        print("FAILED:\(lineno): \(sparql)")
        return (0, 0)
    }
}

let multi = results.map { $0.0 }.reduce(0, {$0 + $1})
let stars = results.map { $0.1 }.reduce(0, {$0 + $1})
let frac = String(format: "%.1f%%", 100.0 * Double(multi) / Double(stars))
print("\(multi)/\(stars) (\(frac)) stars used a predicate more than once")












