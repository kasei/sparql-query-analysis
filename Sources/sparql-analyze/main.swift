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

// example of how to use highlightedAlgebra to highlight a sparql query string with the parts that contribute to specific algebra patterns
func printHighlightedQuery(_ sparql : String, printAlgebra: Bool) {
    do {
        guard let data = sparql.data(using: .utf8) else { return }
        let stream = InputStream(data: data)
        stream.open()
        let serialized = try highlightedAlgebra(sparql, printAlgebra) {
            switch $0 {
            case .innerJoin:
                return ("Join", 6)
//            case .bgp, .triple:
//                return ("BGP", 5)
            case .filter:
                return ("Filter", 4)
            case .path:
                return ("Path", 3)
            case .order:
                return ("Sorting", 2)
//            case .leftOuterJoin:
//                return ("Optional", 1)
            case .slice:
                return ("Slicing", 5)
            default:
                return nil
            }
        }
        
        if let serialized {
            print(serialized)
        }
    } catch let e {
        print("*** \(e)")
    }
}

func analyze(_ sparql : String) throws {
    guard var parser = SPARQLParser(string: sparql) else { fatalError("Failed to construct SPARQL parser") }
    let query = try parser.parseQuery()
    let algebra = query.algebra
    let m = MultiAnalyzer()
    let reporter = Reporter()
    let issues = try m.analyze(sparql: sparql, query: query, algebra: algebra, reporter: reporter)
    print("\n")
    print("\(issues) isues found.")
}

let ser = SPARQLSerializer(prettyPrint: false)
let a = QueryAnalysis()
try a.forEachQuery { (lineno, sparql, flags, args) -> Int in
    do {
        try analyze(sparql)
        return 0
    } catch {
        let sparql = ser.reformat(sparql)
        print("ERROR:\(lineno): Failed to analyze query: \(error)")
        print("FAILED:\(lineno): \(sparql)")
        return 0
    }
}
