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

struct PathRewriter {
    var next : Int
    var terms : [Term:Term]
    
    init () {
        next = 1
        terms = [:]
    }
    
    mutating func rewrittenIRI(for term: Term) -> Term {
        if let tt = terms[term] {
            return tt
        } else {
            let tt = Term(iri: "iri\(next)")
            next += 1
            terms[term] = tt
            return tt
        }
    }
    
    mutating func rewrite(_ path : PropertyPath) -> PropertyPath {
        switch path {
        case .link(let t):
            return .link(rewrittenIRI(for: t))
        case let .alt(lhs, rhs):
            let l = rewrite(lhs)
            let r = rewrite(rhs)
            if l < r {
                return .seq(l, r)
            } else {
                return .seq(r, l)
            }
        case let .seq(lhs, rhs):
            let l = rewrite(lhs)
            let r = rewrite(rhs)
            return .seq(l, r)
        case let .inv(pp):
            return .inv(rewrite(pp))
        case let .nps(iris):
            let i = iris.map { rewrittenIRI(for: $0) }.sorted()
            return .nps(i)
        case let .star(pp):
            return .star(rewrite(pp))
        case let .plus(pp):
            return .plus(rewrite(pp))
        case let .zeroOrOne(pp):
            return .zeroOrOne(rewrite(pp))
        }
    }
}

func countComplexElements(_ path: PropertyPath) -> Int {
    switch path {
    case .link, .nps, .plus(.link), .star(.link):
        return 0
    case .inv(let pp):
        return countComplexElements(pp)
    case .alt(let lhs, let rhs), .seq(let lhs, let rhs):
        return countComplexElements(lhs) + countComplexElements(rhs)
    case .plus(let pp), .star(let pp):
        return 1 + countComplexElements(pp)
    case .zeroOrOne(let pp):
        return countComplexElements(pp)
    }
}

@discardableResult
func extractPaths(from sparql : String, serializer ser : SPARQLSerializer, rename: Bool) throws -> (Int, Int) {
    guard var p = SPARQLParser(string: sparql) else { fatalError("Failed to construct SPARQL parser") }
    let a = try p.parseAlgebra()
    var totalPaths = 0
    var complexPathElements = 0
    try a.walk { (algebra) in
        var rewriter = PathRewriter()
        switch algebra {
        case let .path(_, pp, _):
            let s : Node = .variable("s", binding: true)
            let o : Node = .variable("o", binding: true)
            let p = rename ? rewriter.rewrite(pp) : pp
            let complex = countComplexElements(pp)
            complexPathElements += complex
            let sparql = try ser.serialize(.path(s, p, o))
            if complex > 0 {
                print("COMPLEX PATH: \(sparql)")
            }
            totalPaths += 1
        //            print("\(p)")
        default:
            break
        }
    }
    return (totalPaths, complexPathElements)
}

let ser = SPARQLSerializer(prettyPrint: false)
let a = QueryAnalysis()
let results = try a.forEachQuery { (lineno, sparql, flags, args) -> (Int, Int) in
    let rename = flags.contains("-r")
    do {
        let pair = try extractPaths(from: sparql, serializer: ser, rename: rename)
        let (total, complex) = pair
//        print("INFO: \(count) paths found in query")
        return pair
    } catch {
        let sparql = ser.reformat(sparql)
        print("ERROR:\(lineno): Failed to extract paths from query: \(error)")
        print("FAILED:\(lineno): \(sparql)")
        return (0, 0)
    }
}

var total = 0
var complex = 0
for pair in results {
    total += pair.0
    complex += pair.1
}
print("\(complex) complex plus/star paths in \(total) total path patterns")
