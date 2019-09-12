//
//  Created by Smirnov Maxim on 29/11/2018.
//  Copyright © 2018 Smirnov Maxim. All rights reserved.
//

import Foundation

enum Generator {
    /// Function that generates init.
    /// - Parameter selection: Array of selected lines.
    /// - Parameter indentation:
    /// - Parameter leadingIndent:
    static func generate(selection: [String], indentation: String, leadingIndent: String) -> [String] {
        let variables = VariablesGenerator.generate(from: selection).filter { !$0.needToSkipInInitGeneration }
        guard !variables.isEmpty else { return ["public init() { }"] }
        let generatedInit = generateInit(variables.map(argument))
        let expressions = variables.map { expression(variable: $0, indentation: indentation) }
        let lines = (generatedInit + expressions + ["}"]).map { "\(leadingIndent)\($0)" }

        return lines
    }

    private static func expression(variable: Variable, indentation: String) -> String {

        if variable.name.first == "_" {
            var name = variable.name
            name.removeFirst()
            return "\(indentation)\(variable.name) = \(name)"
        }

        return "\(indentation)self.\(variable.name) = \(variable.name)"
    }

    private static func argument(variable: Variable) -> String {

        var name = variable.name
        if variable.name.first == "_" {
            name.removeFirst()
        }

        return "\(name): \(addEscapingAttributeIfNeeded(to: variable.type))"
    }

    private static func generateInit(_ arguments: [String]) -> [String] {

        guard arguments.joined(separator: ", ").count > 80 else {
            return ["public init(" + arguments.joined(separator: ", ") + ") {"]
        }

        var indent: String = ""
        "public init(".forEach { _ in
            indent.append(" ")
        }

        var result: [String] = []

        for (i, argument) in arguments.enumerated() {

            if i == 0 {
                var line = "public init(" + argument
                if arguments.count != 1 {
                    line.append(",")
                } else {
                    line.append(") {")
                }
                result.append(line)
                continue
            }

            if i == (arguments.count - 1) {
                result.append(indent + argument + ") {")
                continue
            }

            result.append(indent + argument + ",")
        }

        return result
    }

    private static func addEscapingAttributeIfNeeded(to typeString: String) -> String {
        let predicate = NSPredicate(format: "SELF MATCHES %@", "\\(.*\\)->.*")
        if predicate.evaluate(with: typeString.replacingOccurrences(of: " ", with: "")),
            !isOptional(typeString: typeString) {
            return "@escaping " + typeString
        } else {
            return typeString
        }
    }

    private static func isOptional(typeString: String) -> Bool {
        guard typeString.hasSuffix("!") || typeString.hasSuffix("?") else {
            return false
        }
        var balance = 0
        var indexOfClosingBraceMatchingFirstOpenBrace: Int?

        for (index, character) in typeString.enumerated() {
            if character == "(" {
                balance += 1
            } else if character == ")" {
                balance -= 1
            }
            if balance == 0 {
                indexOfClosingBraceMatchingFirstOpenBrace = index
                break
            }
        }

        return indexOfClosingBraceMatchingFirstOpenBrace == typeString.count - 2
    }

}

private enum VariablesGenerator {

    static func generate(from selection: [String]) -> [Variable] {
        return selection
            .multiLineCommentsRemoved
            .map(removeSingleLineComment)
            .map(removeNewLineSymbol)
            .map { $0.split(separator: " ") }
            .map(removeAllTypePrefixes)
            .map(convertPrepreparedArrayToVariable)
            .compactMap { $0 }
    }

    private static func removeSingleLineComment(for string: String) -> String {
        var mutable = string
        if let startOfComments = mutable.range(of: "//") {
            mutable.removeSubrange(startOfComments.lowerBound..<mutable.endIndex)
        }
        return mutable
    }

    private static func removeNewLineSymbol(for string: String) -> String {
        var mutable = string
        if let newLineSymbolPosition = mutable.range(of: "\n") {
            mutable.removeSubrange(newLineSymbolPosition)
        }
        return mutable
    }

    private static func removeAllTypePrefixes(for array: [Substring]) -> [Substring] {
        var mutable = array
        guard let mutabilityIdentifierIndex = mutable.firstIndex(where: { $0.contains("var") || $0.contains("let") }) else { return [] }
        if mutabilityIdentifierIndex == mutable.startIndex { return mutable }
        mutable.removeSubrange(mutable.startIndex..<mutabilityIdentifierIndex)
        return mutable
    }

    private static func convertPrepreparedArrayToVariable(_ array: [Substring]) -> Variable? {
        guard array.count >= 3 else { return nil }
        var line = array.map(String.init)
        let mutabilityIdentifier = line.removeFirst()
        var name = line.removeFirst()
        name.removeAll { $0 == ":" }
        let type = line.joined(separator: " ")
        return Variable(name: name, type: type, isMutable: mutabilityIdentifier.contains("var"))
    }
}

private extension Array where Element == String {
    var multiLineCommentsRemoved: [String] {
        var selection = self
        if let openCommentIndex = selection.firstIndex(where: { $0.contains("/*") }), openCommentIndex != selection.endIndex {
            let closeCommentIndex = selection.firstIndex { $0.contains("*/") } ?? selection.endIndex
            selection.removeSubrange(openCommentIndex...closeCommentIndex)
        }
        if selection.contains(where: { $0.contains("/*") || $0.contains("*/") }) {
            selection = selection.multiLineCommentsRemoved
        }

        return selection
    }
}
