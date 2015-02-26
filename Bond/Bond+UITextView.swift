//
//  Bond+UITextView.swift
//  Bond
//
//  Created by Srđan Rašić on 26/02/15.
//  Copyright (c) 2015 Bond. All rights reserved.
//

import UIKit

private var textBondHandleUITextView: UInt8 = 0;

extension UITextView: Bondable {
  
  public var textBond: Bond<String> {
    if let b: AnyObject = objc_getAssociatedObject(self, &textBondHandleUITextView) {
      return (b as? Bond<String>)!
    } else {
      let b = Bond<String>() { [unowned self] v in
        self.text = v
      }
      objc_setAssociatedObject(self, &textBondHandleUITextView, b, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
      return b
    }
  }
  
  public var designatedBond: Bond<String> {
    return self.textBond
  }
}
