//
//  FunFile.swift
//  MoeBamba
//
//  Created by John N Blanchard on 12/18/18.
//  Copyright © 2018 JNB. All rights reserved.
//

import Foundation
import UIKit

func add<T: Numeric>(a: T, b: T) -> T {
  return a + b
}

let a = CGFloat(2.5)
let b = CGFloat(2.7)

let aandb = add(a: a, b: b)


extension Array where Element == Numeric {
  
  
}
