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

extension Algebra {
    var isOrdered: Bool {
        switch self {
        case .unionIdentity, .joinIdentity, .table, .quad, .triple, .bgp, .innerJoin, .leftOuterJoin, .union:
            return false
        case .namedGraph, .minus, .service, .path, .aggregate, .window:
            return false
        case .filter(let c, _), .project(let c, _), .extend(let c, _, _), .distinct(let c), .reduced(let c), .slice(let c, _, _):
            return c.isOrdered
        case .subquery(let q):
            return q.algebra.isOrdered
        case .order:
            return true
        }
    }
}

extension Query {
    var isOrderedWithoutSlice: Bool {
        if !algebra.isOrdered { return false }
        switch self.algebra {
        case .slice, .project(.slice, _):
            return false
        default:
            return true
        }
    }
}

@discardableResult
func extractSortedSubqueries(from sparql : String, serializer ser : SPARQLSerializer, rename: Bool) throws -> Int {
    guard var p = SPARQLParser(string: sparql) else { fatalError("Failed to construct SPARQL parser") }
    let a = try p.parseAlgebra()
    var count = 0
    try a.walk { (algebra) in
        switch algebra {
        case .subquery(let q) where q.isOrderedWithoutSlice:
            let ser = SPARQLSerializer()
            print(ser.reformat(sparql))
            count += 1
        default:
            break
        }
    }
    return count
}

let ser = SPARQLSerializer(prettyPrint: false)
let a = QueryAnalysis()
try a.forEachQuery { (lineno, sparql, flags, args) -> Int in
    let rename = flags.contains("-r")
    do {
        let count = try extractSortedSubqueries(from: sparql, serializer: ser, rename: rename)
//        print("INFO: \(count) paths found in query")
        return count
    } catch {
        let sparql = ser.reformat(sparql)
        print("ERROR:\(lineno): Failed to extract sorted subqueries from query: \(error)")
        print("FAILED:\(lineno): \(sparql)")
        return 0
    }
}
