//
//  UselessOptionalAnalyzer.swift
//
//
//  Created by Gregory Todd Williams on 10/11/23.
//

import SPARQLSyntax


public struct UselessOptionalAnalyzer: Analyzer {
    public let name = "UselessOptionalAnalyzer"
    public var description = "Finds OPTIONAL patterns whose left-hand side is empty (making the OPTIONAL into just a non-OPTIONAL)."
    
    public func analyze(sparql: String, query: SPARQLSyntax.Query, algebra: SPARQLSyntax.Algebra, reporter: Reporter) throws -> Int {
        var count = 0
        try algebra.walkWithSubqueries { (a) in
            switch a {
            case .leftOuterJoin(.joinIdentity, _, _):
                let identifier : ReportIdentifier = .algebra({
                    if $0 == a {
                        return ("Issue", 0)
                    }
                    return nil
                })
                let message = "OPTIONAL is useless as its left-hand-side argument is empty."
                try reporter.reportIssue(sparql: sparql, query: query, algebra: algebra, analyzer: self, code: "1", message: message, identifier: identifier)
                count += 1
            default:
                break
            }
        }
        return count
    }

}

