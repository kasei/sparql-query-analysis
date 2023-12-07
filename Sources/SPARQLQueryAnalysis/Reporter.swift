//
//  Reporter.swift
//  
//
//  Created by Gregory Todd Williams on 10/11/23.
//

import Foundation
import SPARQLSyntax
import Rainbow

public typealias AlgebraIdentifier = (Algebra) -> (String, Int)?

func makeHighlighter(color: KeyPath<String, String>) -> SPARQLSerializer.Highlighter {
    return { (s, state) in
        if case .highlighted = state {
            return s[keyPath: color]
        } else {
            return s
        }
    }
}

func color(for value: Int) -> KeyPath<String, String> {
    let colors : [KeyPath<String, String>] = [\.red, \.yellow, \.green, \.blue, \.magenta]
    return colors[value % colors.count]
}

public func highlightedAlgebra(_ sparql : String, _ printAlgebra: Bool, include : @escaping AlgebraIdentifier) throws -> String? {
    return try highlightedAlgebra(sparql, printAlgebra, include: include, exclude: { (_) in return nil })
}

func highlightedAlgebra(_ sparql : String, _ printAlgebra: Bool, include includePredicate : @escaping AlgebraIdentifier, exclude excludePredicate: @escaping AlgebraIdentifier) throws -> String? {
    var parser = SPARQLParser(string: sparql)!
    let q = try parser.parseQuery()
    let a = q.algebra
    
    var names = [Int: String]()
    var highlight = [Int: Set<ClosedRange<Int>>]()
    var exceptions = [Int: Set<ClosedRange<Int>>]()
    let walkConfig = WalkConfig(type: WalkType(descendIntoAlgebras: true, descendIntoSubqueries: true, descendIntoExpressions: false), algebraHandler: { (algebra) in
        let ranges = parser.getTokenRange(for: algebra)
        
        if let tuple = includePredicate(algebra) {
            let name = tuple.0
            let i = tuple.1
            names[i] = name
            for r in ranges {
                highlight[i, default: []].insert(r)
            }
        }
//        
//        if ranges.isEmpty {
////            print("*** No range for algebra: \(algebra.serialize())")
////            print("--- \n\(sparql)\n--- \n")
//        } else {
////            algebraToTokens[algebra] = ranges
//        }
    })
    try a.walk(config: walkConfig)

    let walkConfig2 = WalkConfig(type: WalkType(descendIntoAlgebras: true, descendIntoSubqueries: true, descendIntoExpressions: false), algebraHandler: { (algebra) in
        let ranges = parser.getTokenRange(for: algebra)
        
        if let tuple = excludePredicate(algebra) {
            let name = tuple.0
            let i = tuple.1
            names[i] = name
            for r in ranges {
                exceptions[i, default: []].insert(r)
            }
        }
    })
    try a.walk(config: walkConfig2)

    if !highlight.isEmpty {
        let ser = SPARQLSerializer(prettyPrint: true)
        let highlighterMap = Dictionary(uniqueKeysWithValues: highlight.map {
            let name = names[$0.key] ?? "\($0.key)"
            let highlighter = makeHighlighter(color: color(for: $0.key))
            var tokenSet = $0.value
            if let excludeSet = exceptions[$0.key] {
                // now remove some tokens from the set. to do this, first explode the closedrange<int> values to single-element ranges.
                // then remove the excluded token range elements, and use the resulting set<closedrange<int>> as the hightlighted set.
                var includeRange = Set<ClosedRange<Int>>()
                for r in tokenSet {
                    for i in r {
                        includeRange.insert(i...i)
                    }
                }
                for r in excludeSet {
                    for i in r {
                        includeRange.remove(i...i)
                    }
                }
                tokenSet = includeRange
            }
            return (tokenSet, (name, highlighter))
        })

        var result = ""
        let (h, _) = ser.reformatHighlightingRanges(sparql, highlighterMap: highlighterMap)
//        if let names = names {
//            for name in names.sorted() {
//                result += "- \(name)\n"
//            }
//        }
//        result += "\n"
        result += h
        if printAlgebra {
            result += a.serialize()
        }
        return result
    }
    return nil
}

public enum ReportIdentifier {
    case algebra(AlgebraIdentifier)
    case tokenSet(Set<SPARQLToken>)
    case algebraDifference(AlgebraIdentifier, AlgebraIdentifier)
    case none
}

public protocol Reporter {
    var printIssues: Bool { get }
    var printSummary: Bool { get }
    func reportIssue(sparql: String, query: Query, algebra: Algebra, analyzer: Analyzer, code: String, message: String, identifier: ReportIdentifier) throws
}

public class ConsoleReporter: Reporter {
    public var printIssues: Bool
    public var printSummary: Bool
    public var summary: [String: Int]
    
    public init(printIssues: Bool = true, printSummary: Bool = true) {
        self.printIssues = printIssues
        self.printSummary = printSummary
        self.summary = [:]
    }
    
    public func reportIssue(sparql: String, query: Query, algebra: Algebra, analyzer: Analyzer, code: String, message: String, identifier: ReportIdentifier) throws {
        summary[analyzer.name, default: 0] += 1
        guard printIssues else { return }
        let issue = "ISSUE".red
        print("\(issue): \(analyzer.name): \(message)")
        switch identifier {
        case .algebra(let i):
            let printAlgebra = false
            if let serialized = try highlightedAlgebra(sparql, printAlgebra, include: i, exclude: { (_) in return nil }) {
                print(serialized)
            }
        case let .algebraDifference(include, exclude):
            let printAlgebra = false
            if let serialized = try highlightedAlgebra(sparql, printAlgebra, include: include, exclude: exclude) {
                print(serialized)
            }
        case .tokenSet(let tokens):
            let s = SPARQLSerializer(prettyPrint: true)
            print(s.reformatHighlightingTokens(sparql, tokens: tokens))
        case .none:
            break
        }
    }
    
    public func reportSummary(queryCount: Int) {
        guard printSummary else { return }
        let total = summary.values.reduce(0, +)
        print("\(queryCount) total queries analyzed.")
        print("\(total) total issues found", terminator: "")
        print((total > 0) ? ":" : ".")
        for entry in summary.sorted(by: { $0.1 > $1.1 }) {
            let message = String(format: "%6d %@", entry.value, entry.key)
            print("- \(message)")
        }
    }
}

