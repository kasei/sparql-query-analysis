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
func analyzePredicates(from sparql : String) throws -> (Int, Int) {
    guard var p = SPARQLParser(string: sparql) else { fatalError("Failed to construct SPARQL parser") }
    let a = try p.parseAlgebra()
    
    var triples = 0
    var unbound = 0
    try a.walk { (algebra) in
        guard case .bgp(let tp) = algebra else { return }
        for t in tp {
            triples += 1
            if case .variable = t.predicate {
                unbound += 1
            }
        }
    }
    
    if unbound > 0 {
        let ser = SPARQLSerializer()
        print(ser.reformat(sparql))
        return (1, 1)
    } else {
        return (0, 1)
    }
//    return (unbound, triples)
}

let a = QueryAnalysis()
let results = try a.forEachQuery { (lineno, sparql, flags, args) -> (Int, Int) in
    do {
        let count = try analyzePredicates(from: sparql)
        return count
    } catch {
        print("ERROR:\(lineno): Failed to process query: \(error)")
        print("FAILED:\(lineno): \(sparql)")
        return (0, 0)
    }
}

let matches = results.map { $0.0 }.reduce(0, {$0 + $1})
let total = results.map { $0.1 }.reduce(0, {$0 + $1})
let frac = String(format: "%.1f%%", 100.0 * Double(matches) / Double(total))
print("\(matches)/\(total) (\(frac)) queries have an unbound predicate")

