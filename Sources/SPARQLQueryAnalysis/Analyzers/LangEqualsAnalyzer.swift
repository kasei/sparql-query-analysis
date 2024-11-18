//
//  SubquerySortAnalyzer.swift
//  
//
//  Created by Gregory Todd Williams on 10/11/23.
//

import SPARQLSyntax

extension Expression {
    var hasLangEqualityTest: Bool {
        var r = false
        do {
            try self.walk { expr in
                switch expr {
                case .eq(.lang(_), _), .eq(_, .lang(_)):
                    r = true
                default:
                    break
                }
            }
        } catch {}
        return r
    }
}

public struct LangEqualsAnalyzer: Analyzer {
    public let name = "LangEquals"
    public var description = "Finds equality tests for literal language values (instead of using LANGMATCHES)."
    
    public func analyze(sparql: String, query: SPARQLSyntax.Query, algebra: SPARQLSyntax.Algebra, reporter: Reporter) throws -> Int {
        var count = 0
        try algebra.walkWithSubqueries { (algebra) in
            switch algebra {
            case .filter(_, let expr), .extend(_, let expr, _), .leftOuterJoin(_, _, let expr):
                var identifier : ReportIdentifier = .none
                if expr.hasLangEqualityTest {
                    identifier = .algebra({
                        if $0 == algebra {
                            return ("Issue", 0)
                        }
                        return nil
                    })
                }
                
                try reporter.reportIssue(sparql: sparql, query: query, algebra: algebra, analyzer: self, code: "1", message: "found expr with equality test on LANG value", identifier: identifier)
//                let ser = SPARQLSerializer()
//                print(ser.reformat(sparql))
                count += 1
            default:
                break
            }
        }
        return count
    }

}
