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

@discardableResult
func extractPaths(from sparql : String, serializer ser : SPARQLSerializer, rename: Bool) throws -> Int {
    guard var p = SPARQLParser(string: sparql) else { fatalError("Failed to construct SPARQL parser") }
    let a = try p.parseAlgebra()
    var count = 0
    try a.walk { (algebra) in
        var rewriter = PathRewriter()
        switch algebra {
        case let .path(_, pp, _):
            let s : Node = .variable("s", binding: true)
            let o : Node = .variable("o", binding: true)
            let p = rename ? rewriter.rewrite(pp) : pp
            let sparql = try ser.serialize(.path(s, p, o))
            print("PATH: \(sparql)")
            count += 1
        //            print("\(p)")
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
        let count = try extractPaths(from: sparql, serializer: ser, rename: rename)
//        print("INFO: \(count) paths found in query")
        return count
    } catch {
        let sparql = ser.reformat(sparql)
        print("ERROR:\(lineno): Failed to extract paths from query: \(error)")
        print("FAILED:\(lineno): \(sparql)")
        return 0
    }
}
