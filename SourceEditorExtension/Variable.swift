//
//  Created by Maxim Smirnov on 12/09/2019.
//  Copyright © 2019 atimca.com. All rights reserved.
//

struct Variable {

    let name: String
    let type: String
    let isMutable: Bool

    var containsDefaultValue: Bool {
        return type.contains("=")
    }
    var isComputed: Bool {
        return type.contains(" {")
    }
}

extension Variable {
    var needToSkipInInitGeneration: Bool {
        if !isMutable, containsDefaultValue {
            return true
        }

        if isComputed {
            return true
        }

        return false
    }
}
