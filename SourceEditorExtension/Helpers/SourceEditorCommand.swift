//
//  Created by Smirnov Maxim on 29/11/2018.
//  Copyright © 2018 Smirnov Maxim. All rights reserved.
//

import Foundation
import XcodeKit

enum GenerationError: Swift.Error {
    case notSwiftLanguage
    case noSelection
    case invalidSelection
    case parseError
}

class SourceEditorCommand: NSObject, XCSourceEditorCommand {

    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Swift.Error?) -> Void) {
        do {
            try generateInitializer(invocation: invocation)
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }

    private func generateInitializer(invocation: XCSourceEditorCommandInvocation) throws {
        guard invocation.buffer.contentUTI == "public.swift-source" else {
            throw GenerationError.notSwiftLanguage
        }
        guard let selection = invocation.buffer.selections.firstObject as? XCSourceTextRange else {
            throw GenerationError.noSelection
        }

        let selectedText: [String]
        if selection.start.line == selection.end.line {
            selectedText = [String(
                (invocation.buffer.lines[selection.start.line] as! String).utf8
                    .prefix(selection.end.column)
                    .dropFirst(selection.start.column)
                )!]
        } else {
            selectedText = [String((invocation.buffer.lines[selection.start.line] as! String).utf8.dropFirst(selection.start.column))!]
                + ((selection.start.line+1)..<selection.end.line).map { invocation.buffer.lines[$0] as! String }
                + [String((invocation.buffer.lines[selection.end.line] as! String).utf8.prefix(selection.end.column))!]
        }

        var initializer = Generator.generate(
            selection: selectedText,
            indentation: indentSequence(for: invocation.buffer),
            leadingIndent: leadingIndentation(from: selection, in: invocation.buffer)
        )

        initializer.insert("", at: 0) // separate from selection with empty line

        let targetRange = selection.end.line + 1 ..< selection.end.line + 1 + initializer.count
        invocation.buffer.lines.insert(initializer, at: IndexSet(integersIn: targetRange))
    }
}

private func indentSequence(for buffer: XCSourceTextBuffer) -> String {
    return buffer.usesTabsForIndentation
        ? "\t"
        : String(repeating: " ", count: buffer.indentationWidth)
}

private func leadingIndentation(from selection: XCSourceTextRange, in buffer: XCSourceTextBuffer) -> String {
    let firstLineOfSelection = buffer.lines[selection.start.line] as! String

    if let nonWhitespace = firstLineOfSelection.rangeOfCharacter(from: CharacterSet.whitespaces.inverted) {
        return String(firstLineOfSelection.prefix(upTo: nonWhitespace.lowerBound))
    } else {
        return ""
    }
}
