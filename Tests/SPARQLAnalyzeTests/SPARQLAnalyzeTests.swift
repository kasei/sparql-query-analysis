import XCTest
import Foundation
import SPARQLSyntax
@testable import SPARQLQueryAnalysis

public class TestReporter: Reporter {
    public let printIssues = true
    public let printSummary = true
    public var summary: [String: Int]
    
    public init() {
        self.summary = [:]
    }
    
    public func reportIssue(sparql: String, query: Query, algebra: Algebra, analyzer: Analyzer, code: String, message: String, identifier: ReportIdentifier) throws {
        summary[analyzer.name, default: 0] += 1
    }
    
    public func reportSummary(queryCount: Int) {
//        guard printSummary else { return }
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


// swiftlint:disable type_body_length
class SPARQLAnalyzeTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func analyzer(_ analyzer: Analyzer, resultsInNoWarningsForQuery sparql: String) throws {
        guard var parser = SPARQLParser(string: sparql) else { fatalError("Failed to construct SPARQL parser") }
        let query = try parser.parseQuery()
        let algebra = query.algebra
        let reporter = TestReporter()
        _ = try analyzer.analyze(sparql: sparql, query: query, algebra: algebra, reporter: reporter)
        XCTAssertEqual(0, reporter.summary.count)
    }
    
    func analyzer(_ analyzer: Analyzer, resultsInKey messageKey: String, forQuery sparql: String) throws {
        guard var parser = SPARQLParser(string: sparql) else { fatalError("Failed to construct SPARQL parser") }
        let query = try parser.parseQuery()
        let algebra = query.algebra
        let reporter = TestReporter()
        _ = try analyzer.analyze(sparql: sparql, query: query, algebra: algebra, reporter: reporter)
        XCTAssertNotNil(reporter.summary.index(forKey: messageKey))
    }
    
    func testSubquerySortAnalyzer() throws {
        try analyzer(SubquerySortAnalyzer(), resultsInNoWarningsForQuery: "SELECT * WHERE { ?s ?p ?o { SELECT * WHERE { ?s ?p 1 } } }")
        try analyzer(SubquerySortAnalyzer(), resultsInNoWarningsForQuery: "SELECT * WHERE { ?s ?p ?o { SELECT * WHERE { ?s ?p 1 } LIMIT 10 } }")
        try analyzer(SubquerySortAnalyzer(), resultsInNoWarningsForQuery: "SELECT * WHERE { ?s ?p ?o { SELECT * WHERE { ?s ?p 1 } ORDER BY ?s LIMIT 10 } }")
        try analyzer(SubquerySortAnalyzer(), resultsInKey: "SubqueryWithSort", forQuery: "SELECT * WHERE { ?s ?p ?o { SELECT * WHERE { ?s ?p 1 } ORDER BY ?s } }")
        try analyzer(SubquerySortAnalyzer(), resultsInKey: "SubqueryWithSort", forQuery: "SELECT * WHERE { { SELECT * WHERE { ?s ?p 1 } ORDER BY ?s } }")
    }

    func testUselessOptionalAnalyzer2() throws {
        // OPTIONAL is important for the cardinality of ?o in the GROUP_CONCAT
        try analyzer(UselessOptionalAnalyzer2(), resultsInNoWarningsForQuery: """
        PREFIX ex: <http://example.org/>
        select ?s (GROUP_CONCAT(?o) AS ?o_concat) where {
            ?s ?p ?o .
            OPTIONAL {
                ?o a ?type
            }
        }
        GROUP BY ?s
        """)

        // OPTIONAL is important for the cardinality of ?o in the SUM (even though the cardinality is not important for the GROUP_CONCAT)
        try analyzer(UselessOptionalAnalyzer2(), resultsInNoWarningsForQuery: """
        PREFIX ex: <http://example.org/>
        select ?s (GROUP_CONCAT(DISTINCT ?o) AS ?o_concat) (SUM(?o) AS ?o_sum) where {
            ?s ?p ?o .
            OPTIONAL {
                ?o a ?type
            }
        }
        GROUP BY ?s
        """)

        // OPTIONAL is NOT important because ?s is grouped and cardinality of ?o disappears in the GROUP_CONCAT(DISTINCT)
        try analyzer(UselessOptionalAnalyzer2(), resultsInKey: "UselessOptionalAnalyzer2", forQuery: """
        PREFIX ex: <http://example.org/>
        select ?s (GROUP_CONCAT(DISTINCT ?o) AS ?o_concat) where {
            ?s ?p ?o .
            OPTIONAL {
                ?o a ?type
            }
        }
        GROUP BY ?s
        """)

        // OPTIONAL is NOT important because ?s is grouped and nothing else is projected
        try analyzer(UselessOptionalAnalyzer2(), resultsInKey: "UselessOptionalAnalyzer2", forQuery: """
        PREFIX ex: <http://example.org/>
        select ?s where {
            {
                ?s ?p ?o .
                OPTIONAL {
                    ?o a ?type
                }
            }
        }
        GROUP BY ?s
        """)

        // OPTIONAL is NOT important because ?p and ?o are grouped and nothing else is projected
        try analyzer(UselessOptionalAnalyzer2(), resultsInKey: "UselessOptionalAnalyzer2", forQuery: """
        PREFIX ex: <http://example.org/>
        select ?p where {
            {
                ?s ?p ?o .
                OPTIONAL {
                    ?o ex:type ex:German_novellist ;
                        ex:prop ?x
                }
            }
        }
        GROUP BY ?p ?o
        """)

        // OPTIONAL is NOT important because ?p and ?o are grouped and cardinality of ?o disappears in the GROUP_CONCAT(DISTINCT) and MIN()
        try analyzer(UselessOptionalAnalyzer2(), resultsInKey: "UselessOptionalAnalyzer2", forQuery: """
        PREFIX ex: <http://example.org/>
        select ?p (GROUP_CONCAT(DISTINCT ?o) AS ?o_concat) (MIN(?o) AS ?o_min) where {
            {
                ?s ?p ?o .
                OPTIONAL {
                    ?o ex:type ex:German_novellist ;
                        ex:prop ?x
                }
            }
        }
        GROUP BY ?p ?o
        """)
    }

}
