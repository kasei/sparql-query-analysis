//
//  Analyzer.swift
//  Kineo
//
//  Created by Gregory Todd Williams on 6/24/16.
//  Copyright © 2016 Gregory Todd Williams. All rights reserved.
//

import Foundation
import SPARQLSyntax


public protocol Analyzer: CustomStringConvertible {
    var name: String { get }
    func analyze(sparql: String, query: Query, algebra: Algebra, reporter: Reporter) throws -> Int
}

public struct MultiAnalyzer: Analyzer {
    public let name: String = "MultiAnalyzer"
    public let description: String = "MultiAnalyzer"
    var analyzers: [Analyzer]
    public init() {
        analyzers = [
            SubquerySortAnalyzer(),
            UnboundFilterVariableAnalyzer(),
            UselessOptionalAnalyzer(),
            UselessOptionalAnalyzer2(),
            LangEqualsAnalyzer()
        ]
    }
    
    @discardableResult
    public func analyze(sparql: String, query: Query, algebra: Algebra, reporter: Reporter) throws -> Int {
        var issues = 0
        for a in analyzers {
            do {
                issues += try a.analyze(sparql: sparql, query: query, algebra: algebra, reporter: reporter)
            } catch let e {
                print("Issue running analyzer \(a.description): \(e)")
            }
        }
        return issues
    }
}






extension Algebra {
    func walkWithSubqueries(_ handler: (Algebra) throws -> ()) throws {
        try handler(self)
        switch self {
        case .unionIdentity, .joinIdentity, .triple, .quad, .path, .bgp, .table:
            return
        case .subquery(let q):
            try q.algebra.walkWithSubqueries(handler)
        case .distinct(let a):
            try a.walkWithSubqueries(handler)
        case .reduced(let a):
            try a.walkWithSubqueries(handler)
        case .project(let a, _):
            try a.walkWithSubqueries(handler)
        case .order(let a, _):
            try a.walkWithSubqueries(handler)
        case .minus(let a, let b):
            try a.walkWithSubqueries(handler)
            try b.walkWithSubqueries(handler)
        case .union(let a, let b):
            try a.walkWithSubqueries(handler)
            try b.walkWithSubqueries(handler)
        case .innerJoin(let a, let b):
            try a.walkWithSubqueries(handler)
            try b.walkWithSubqueries(handler)
        case .leftOuterJoin(let a, let b, _):
            try a.walkWithSubqueries(handler)
            try b.walkWithSubqueries(handler)
        case .extend(let a, _, _):
            try a.walkWithSubqueries(handler)
        case .filter(let a, _):
            try a.walkWithSubqueries(handler)
        case .namedGraph(let a, _):
            try a.walkWithSubqueries(handler)
        case .slice(let a, _, _):
            try a.walkWithSubqueries(handler)
        case .service(_, let a, _):
            try a.walkWithSubqueries(handler)
        case .aggregate(let a, _, _):
            try a.walkWithSubqueries(handler)
        case .window(let a, _):
            try a.walkWithSubqueries(handler)
        }
    }

}
