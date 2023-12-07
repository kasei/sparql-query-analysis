//
//  UselessOptionalAnalyzer2.swift
//
//
//  Created by Gregory Todd Williams on 10/11/23.
//

import SPARQLSyntax

extension Aggregation {
    public var distinct: Bool {
        switch self {
        case .countAll:
            return false
        case .count(_, let distinct),
                .sum(_, let distinct),
                .avg(_, let distinct),
                .groupConcat(_, _, let distinct):
            return distinct
        case .min, .max, .sample:
            return true
        }
    }
    
    public var expression: Expression {
        switch self {
        case .countAll:
            return .node(.bound(.trueValue))
        case .count(let e, _),
                .sum(let e, _),
                .avg(let e, _),
                .groupConcat(let e, _, _),
                .min(let e),
                .max(let e),
                .sample(let e):
            return e
        }
    }
}

extension Algebra {
    enum ProjectionRequirement {
        case all
        case distinct
        case none
        
        func merge(_ other: ProjectionRequirement) -> ProjectionRequirement {
            switch (self, other) {
            case (.all, _), (_, .all):
                return .all
            case (.none, let a), (let a, .none):
                return a
            case (.distinct, .distinct):
                return .distinct
            }
        }
    }
    
    struct DependencyData {
        init (_ variables: Set<String>) {
            d = Dictionary(uniqueKeysWithValues: variables.map { ($0, .all) })
        }
        init (_ d: [String: ProjectionRequirement]) {
            self.d = d
        }
        func project(_ variables: Set<String>) -> DependencyData {
            return DependencyData(d.filter { variables.contains($0.key) })
        }
        func drop(_ variables: Set<String>) -> DependencyData {
            return DependencyData(d.filter { !variables.contains($0.key) })
        }
        func allDistinct() -> DependencyData {
            return DependencyData(Dictionary(uniqueKeysWithValues: d.keys.map { ($0, .distinct) }))
        }
        func distinct(_ variables: Set<String>) -> DependencyData {
            return DependencyData(Dictionary(uniqueKeysWithValues: d.keys.map { ($0, variables.contains($0) ? .distinct : d[$0]!) }))
        }
        func adding(_ variable: String, _ requirement: ProjectionRequirement) -> DependencyData {
            var dd = d
            dd[variable] = requirement
            return DependencyData(dd)
        }
        func adding<C: Collection>(_ variables: C, _ requirement: ProjectionRequirement) -> DependencyData where C.Element == String {
            var dd = d
            for v in variables {
                dd[v] = requirement
            }
            return DependencyData(dd)
        }
        func merging(_ variable: String, _ requirement: ProjectionRequirement) -> DependencyData {
            var dd = d
            dd[variable] = dd[variable, default: requirement].merge(requirement)
            return DependencyData(dd)
        }
        func merging<C: Collection>(_ variables: C, _ requirement: ProjectionRequirement) -> DependencyData where C.Element == String {
            var dd = d
            for variable in variables {
                dd[variable] = dd[variable, default: requirement].merge(requirement)
            }
            return DependencyData(dd)
        }
        func aggregating(_ groups: [Expression], _ mappings: Set<Algebra.AggregationMapping>) -> DependencyData {
            var dd = d
            for expr in groups {
                for variable in expr.variables {
                    dd[variable] = .distinct
                }
            }
            // other than the group vars, everything other variable has to be mentioned in an aggregation expression.
            // so set them all to .none first, and then they'll be upgraded in the following loop
            for m in mappings {
                dd.removeValue(forKey: m.variableName)
                for variable in m.aggregation.expression.variables {
                    dd[variable] = ProjectionRequirement.none
                }
            }
            
            for m in mappings {
                let agg = m.aggregation
                let e = agg.expression
                let requirement : ProjectionRequirement = agg.distinct ? .distinct : .all
                for variable in e.variables {
                    dd[variable] = dd[variable, default: requirement].merge(requirement)
                }
            }
            return DependencyData(dd)
        }
        func requirement(for variable: String, default def: ProjectionRequirement = .all) -> ProjectionRequirement {
            return d[variable, default: def]
        }
        
        func requirement(for variable: String) -> ProjectionRequirement? {
            return d[variable]
        }

        var d: [String: ProjectionRequirement]
    }
    
    func walk2(dependencies: DependencyData, _ handler: (Algebra, Algebra, Algebra, Expression, Set<String>, Set<String>, DependencyData) throws -> ()) throws {
//        print("========================================================================")
//        print("---- WALK:\n\(self.serialize())")
//        for (key, req) in dependencies.d {
//            print("- \(key): \(req)")
//        }

        switch self {
        case .unionIdentity, .joinIdentity, .triple, .quad, .path, .bgp, .table:
            return
        case .subquery(let q):
            try q.algebra.walk2(dependencies: dependencies, handler)
        case .distinct(let a):
            try a.walk2(dependencies: dependencies.allDistinct(), handler)
        case .reduced(let a):
            try a.walk2(dependencies: dependencies.allDistinct(), handler)
        case .project(let a, let v):
            try a.walk2(dependencies: dependencies.project(v), handler)
        case .order(let a, _):
            try a.walk2(dependencies: dependencies, handler)
        case .minus(let a, let b):
            let jv = a.inscope.intersection(b.inscope)
            try a.walk2(dependencies: dependencies.project(a.inscope), handler)
            try b.walk2(dependencies: dependencies.project(jv).allDistinct(), handler) // join vars are the only thing needed, and they can be distinct
        case .union(let a, let b):
            try a.walk2(dependencies: dependencies.project(a.inscope), handler)
            try b.walk2(dependencies: dependencies.project(b.inscope), handler)
        case .innerJoin(let a, let b):
            let jv = a.inscope.intersection(b.inscope)
            try a.walk2(dependencies: dependencies.adding(jv, .all).project(a.inscope), handler)
            try b.walk2(dependencies: dependencies.adding(jv, .all).project(b.inscope), handler)
        case .leftOuterJoin(let a, let b, let e):
            // TODO: this condition isn't right. the LHS variables also need to be cardinality agnostic
            let distinct_vars = inscope.filter { dependencies.requirement(for: $0, default: .all) == .distinct }
            let unprojected_vars = inscope.filter {
                if let d = dependencies.requirement(for: $0) {
                    return d == .none
                } else {
                    return true
                }
            }
            let vars = distinct_vars.union(unprojected_vars)
            if vars == inscope {
                // all vars resulting from this left join are either unprojected or are cardinality-agnostic
                try handler(self, a, b, e, distinct_vars, unprojected_vars, dependencies)
            }
            
            let ev = e.variables
            let jv = a.inscope.intersection(b.inscope)
            try a.walk2(dependencies: dependencies.adding(jv, .all).project(a.inscope.union(ev)), handler)
            try b.walk2(dependencies: dependencies.adding(jv, .all).project(b.inscope.union(ev)), handler)
        case let .extend(a, e, v):
            let dep = dependencies.drop([v]).merging(e.variables, .all)
            try a.walk2(dependencies: dep, handler)
        case .filter(let a, let e):
            try a.walk2(dependencies: dependencies.merging(e.variables, .all), handler)
        case .namedGraph(let a, .bound(_)):
            try a.walk2(dependencies: dependencies, handler)
        case .namedGraph(let a, .variable(let g, binding: _)):
            try a.walk2(dependencies: dependencies.merging(g, .all), handler)
        case .slice(let a, _, _):
            try a.walk2(dependencies: dependencies, handler)
        case .service(_, let a, _):
            try a.walk2(dependencies: dependencies, handler)
        case let .aggregate(a, groups, mappings):
            try a.walk2(dependencies: dependencies.aggregating(groups, mappings), handler)
        case .window(let a, _): // TODO: handle window
            try a.walk2(dependencies: dependencies, handler)
        }
    }

}
/**
 [WIP] This is in-development. The idea is that some OPTIONAL patterns aren't necessary because they don't produce any new variables (or those variables aren't projected) and the other variables in the left-join whose cardinality might be changed by the OPTIONAL feed into operators where their cardinality isn't meaningful (e.g. DISTINCT projection, non-counting aggregates like MIN, MAX, SAMPLE, or DISTINCT aggregates).
 */
public struct UselessOptionalAnalyzer2: Analyzer {
    public let name = "UselessOptionalAnalyzer2"
    public var description = "Finds OPTIONAL patterns which produce results which do not require the use of OPTIONAL."

    public func analyze(sparql: String, query: SPARQLSyntax.Query, algebra: SPARQLSyntax.Algebra, reporter: Reporter) throws -> Int {
        var count = 0
        let initialDependencies = Algebra.DependencyData(algebra.inscope)
        try algebra.walk2(dependencies: initialDependencies) { (optional, lhs, rhs, e, distinct_vars, unprojected_vars, dependencies) in
            let optionalId : AlgebraIdentifier = {
                if $0 == optional {
                    return ("Issue", 0)
                }
                return nil
            }
            let lhsId : AlgebraIdentifier = {
                if $0 == lhs {
                    return ("Issue", 0)
                }
                return nil
            }
            let identifier : ReportIdentifier = .algebraDifference(optionalId, lhsId)
            let message : String
            let unproj = unprojected_vars.joined(separator: ", ")
            let dist = distinct_vars.joined(separator: ", ")
            if distinct_vars.isEmpty {
                message = "OPTIONAL is useless as all of the variables resulting from it (\(unproj)) are un-projected."
            } else if unprojected_vars.isEmpty {
                message = "OPTIONAL is useless as all of the variables resulting from it (\(dist)) are cardinality-agnostic."
            } else {
                message = "OPTIONAL is useless as all of the variables resulting from it are either un-projected (\(unproj)) or are are cardinality-agnostic (\(dist))."
            }
            try reporter.reportIssue(sparql: sparql, query: query, algebra: algebra, analyzer: self, code: "1", message: message, identifier: identifier)
            count += 1
//            switch a {
//            case .leftOuterJoin(.joinIdentity, _, _):
//                let identifier : ReportIdentifier = .algebra({
//                    if $0 == a {
//                        return ("Issue", 0)
//                    }
//                    return nil
//                })
//                let message = "OPTIONAL is useless as its left-hand-side argument is empty."
//                try reporter.reportIssue(sparql: sparql, query: query, algebra: algebra, analyzer: self, code: "1", message: message, identifier: identifier)
//                count += 1
//            default:
//                break
//            }
        }
        return count
    }

}

