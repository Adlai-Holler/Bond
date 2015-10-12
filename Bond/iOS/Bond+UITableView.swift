//
//  Bond+UITableView.swift
//  Bond
//
//  The MIT License (MIT)
//
//  Copyright (c) 2015 Srdan Rasic (@srdanrasic)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import UIKit

extension NSIndexSet {
  convenience init(array: [Int]) {
    let set = NSMutableIndexSet()
    for index in array {
      set.addIndex(index)
    }
    self.init(indexSet: set)
  }
}

@objc class TableViewDynamicArrayDataSource: NSObject, UITableViewDataSource {
  weak var dynamic: DynamicArray<DynamicArray<UITableViewCell>>?
  @objc weak var nextDataSource: UITableViewDataSource?
  
  init(dynamic: DynamicArray<DynamicArray<UITableViewCell>>) {
    self.dynamic = dynamic
    super.init()
  }
  
  func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    return self.dynamic?.count ?? 0
  }
  
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return self.dynamic?[section].count ?? 0
  }
  
  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    return self.dynamic?[indexPath.section][indexPath.item] ?? UITableViewCell()
  }
  
  // Forwards
  
  func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    if let ds = self.nextDataSource {
      return ds.tableView?(tableView, titleForHeaderInSection: section)
    } else {
      return nil
    }
  }
  
  func tableView(tableView: UITableView, titleForFooterInSection section: Int) -> String? {
    if let ds = self.nextDataSource {
      return ds.tableView?(tableView, titleForFooterInSection: section)
    } else {
      return nil
    }
  }
  
  func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
    if let ds = self.nextDataSource {
      return ds.tableView?(tableView, canEditRowAtIndexPath: indexPath) ?? false
    } else {
      return false
    }
  }
  
  func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
    if let ds = self.nextDataSource {
      return ds.tableView?(tableView, canMoveRowAtIndexPath: indexPath) ?? false
    } else {
      return false
    }
  }
  
  func sectionIndexTitlesForTableView(tableView: UITableView) -> [String]? {
    if let ds = self.nextDataSource {
      return ds.sectionIndexTitlesForTableView?(tableView) ?? []
    } else {
      return []
    }
  }
  
  func tableView(tableView: UITableView, sectionForSectionIndexTitle title: String, atIndex index: Int) -> Int {
    if let ds = self.nextDataSource {
      return ds.tableView?(tableView, sectionForSectionIndexTitle: title, atIndex: index) ?? index
    } else {
      return index
    }
  }
  
  func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    if let ds = self.nextDataSource {
      ds.tableView?(tableView, commitEditingStyle: editingStyle, forRowAtIndexPath: indexPath)
    }
  }
  
  func tableView(tableView: UITableView, moveRowAtIndexPath sourceIndexPath: NSIndexPath, toIndexPath destinationIndexPath: NSIndexPath) {
    if let ds = self.nextDataSource {
      ds.tableView?(tableView, moveRowAtIndexPath: sourceIndexPath, toIndexPath: destinationIndexPath)
    }
  }
}

private class UITableViewDataSourceSectionBond<T>: ArrayBond<UITableViewCell> {
  weak var tableView: UITableView?
  var shouldReloadRows: ((UITableView, [NSIndexPath]) -> [NSIndexPath])?
  var section: Int
  init(tableView: UITableView?, section: Int, disableAnimation: Bool = false, shouldReloadRows: ((UITableView, [NSIndexPath]) -> [NSIndexPath])?) {
    self.tableView = tableView
    self.section = section
    self.shouldReloadRows = shouldReloadRows
    super.init()
    
    self.didInsertListener = { [unowned self] a, i in
      if let tableView: UITableView = self.tableView {
        perform(animated: !disableAnimation) {
          tableView.insertRowsAtIndexPaths(i.map { NSIndexPath(forItem: $0, inSection: self.section) }, withRowAnimation: UITableViewRowAnimation.Automatic)
        }
      }
    }
    
    self.didRemoveListener = { [unowned self] a, i in
      if let tableView = self.tableView {
        perform(animated: !disableAnimation) {
          tableView.deleteRowsAtIndexPaths(i.map { NSIndexPath(forItem: $0, inSection: self.section) }, withRowAnimation: UITableViewRowAnimation.Automatic)
        }
      }
    }
    
    self.didUpdateListener = { [unowned self] a, i in
      if let tableView = self.tableView {
        perform(animated: !disableAnimation) {
          var indexPaths = i.map { NSIndexPath(forItem: $0, inSection: self.section) }
          if let shouldReloadRows = self.shouldReloadRows {
            indexPaths = shouldReloadRows(tableView, indexPaths)
          }
          if !indexPaths.isEmpty {
            tableView.reloadRowsAtIndexPaths(indexPaths, withRowAnimation: UITableViewRowAnimation.Automatic)
          }
        }
      }
    }
    
    self.didResetListener = { [weak self] array in
      if let tableView = self?.tableView {
        tableView.reloadData()
      }
    }
  }
  
  deinit {
    self.unbindAll()
  }
}

public class UITableViewDataSourceBond<T>: ArrayBond<DynamicArray<UITableViewCell>> {
  weak var tableView: UITableView?
  private var dataSource: TableViewDynamicArrayDataSource?
  private var sectionBonds: [UITableViewDataSourceSectionBond<Void>] = []
  public let disableAnimation: Bool
  
  /**
  return only the rows that should be reloaded in the table view.
  Defaults to reloading all rows
  */
  public var shouldReloadRows: ((UITableView, [NSIndexPath]) -> [NSIndexPath])? {
    didSet {
      for section in sectionBonds {
        section.shouldReloadRows = shouldReloadRows
      }
    }
  }
  
  public weak var nextDataSource: UITableViewDataSource? {
    didSet(newValue) {
      dataSource?.nextDataSource = newValue
    }
  }
  
  public init(tableView: UITableView, disableAnimation: Bool = false, shouldReloadRows: ((UITableView, [NSIndexPath]) -> [NSIndexPath])? = nil) {
    self.disableAnimation = disableAnimation
    self.tableView = tableView
    self.shouldReloadRows = shouldReloadRows
    super.init()
    
    self.didInsertListener = { [weak self] array, i in
      if let s = self {
        if let tableView: UITableView = self?.tableView {
          perform(animated: !disableAnimation) {
            tableView.insertSections(NSIndexSet(array: i), withRowAnimation: UITableViewRowAnimation.Automatic)
            
            for section in i.sort(<) {
              let sectionBond = UITableViewDataSourceSectionBond<Void>(tableView: tableView, section: section, disableAnimation: disableAnimation, shouldReloadRows: s.shouldReloadRows)
              let sectionDynamic = array[section]
              sectionDynamic.bindTo(sectionBond)
              s.sectionBonds.insert(sectionBond, atIndex: section)
              
              for var idx = section + 1; idx < s.sectionBonds.count; idx++ {
                s.sectionBonds[idx].section += 1
              }
            }
            
          }
        }
      }
    }
    
    self.didRemoveListener = { [weak self] array, i in
      if let s = self {
        if let tableView = s.tableView {
          perform(animated: !disableAnimation) {
            tableView.deleteSections(NSIndexSet(array: i), withRowAnimation: UITableViewRowAnimation.Automatic)
            for section in i.sort(>) {
              s.sectionBonds[section].unbindAll()
              s.sectionBonds.removeAtIndex(section)
              
              for var idx = section; idx < s.sectionBonds.count; idx++ {
                s.sectionBonds[idx].section -= 1
              }
            }
            
          }
        }
      }
    }
  
    self.didUpdateListener = { [weak self] array, i in
      if let s = self {
        if let tableView = s.tableView {
          perform(animated: !disableAnimation) {
            tableView.reloadSections(NSIndexSet(array: i), withRowAnimation: UITableViewRowAnimation.Automatic)

            for section in i {
              let sectionBond = UITableViewDataSourceSectionBond<Void>(tableView: tableView, section: section, disableAnimation: disableAnimation, shouldReloadRows: s.shouldReloadRows)
              let sectionDynamic = array[section]
              sectionDynamic.bindTo(sectionBond)
              
              self?.sectionBonds[section].unbindAll()
              self?.sectionBonds[section] = sectionBond
            }
            

          }
        }
      }
    }
    
    self.didResetListener = { [weak self] array in
      if let strongSelf = self, tableView = strongSelf.tableView {
        for bond in strongSelf.sectionBonds {
          bond.unbindAll()
        }
        strongSelf.sectionBonds.removeAll(keepCapacity: false)
        
        for section in 0..<array.count {
          let sectionBond = UITableViewDataSourceSectionBond<Void>(tableView: tableView, section: section, disableAnimation: disableAnimation, shouldReloadRows: strongSelf.shouldReloadRows)
          let sectionDynamic = array[section]
          sectionDynamic.bindTo(sectionBond)
          strongSelf.sectionBonds.append(sectionBond)
        }
        tableView.reloadData()
      }
    }
  }
  
  public func bind(dynamic: DynamicArray<UITableViewCell>) {
    bind(DynamicArray([dynamic]))
  }
  
  public override func bind(dynamic: Dynamic<Array<DynamicArray<UITableViewCell>>>, fire: Bool, strongly: Bool) {
    super.bind(dynamic, fire: false, strongly: strongly)
    if let dynamic = dynamic as? DynamicArray<DynamicArray<UITableViewCell>> {
      
      for section in 0..<dynamic.count {
        let sectionBond = UITableViewDataSourceSectionBond<Void>(tableView: self.tableView, section: section, disableAnimation: disableAnimation, shouldReloadRows: shouldReloadRows)
        let sectionDynamic = dynamic[section]
        sectionDynamic.bindTo(sectionBond)
        sectionBonds.append(sectionBond)
      }
      
      dataSource = TableViewDynamicArrayDataSource(dynamic: dynamic)
      dataSource?.nextDataSource = self.nextDataSource
      tableView?.dataSource = dataSource
      tableView?.reloadData()
    }
  }
  
  deinit {
    self.unbindAll()
    tableView?.dataSource = nil
    self.dataSource = nil
  }
}

private var bondDynamicHandleUITableView: UInt8 = 0

extension UITableView /*: Bondable */ {
  public var designatedBond: UITableViewDataSourceBond<UITableViewCell> {
    if let d: AnyObject = objc_getAssociatedObject(self, &bondDynamicHandleUITableView) {
      return (d as? UITableViewDataSourceBond<UITableViewCell>)!
    } else {
      let bond = UITableViewDataSourceBond<UITableViewCell>(tableView: self, disableAnimation: false)
      objc_setAssociatedObject(self, &bondDynamicHandleUITableView, bond, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
      return bond
    }
  }
}

private func perform(animated animated: Bool, block: () -> Void) {
  if !animated {
    UIView.performWithoutAnimation(block)
  } else {
    block()
  }
}

public func ->> <T>(left: DynamicArray<UITableViewCell>, right: UITableViewDataSourceBond<T>) {
  right.bind(left)
}

public func ->> (left: DynamicArray<UITableViewCell>, right: UITableView) {
  left ->> right.designatedBond
}

public func ->> (left: DynamicArray<DynamicArray<UITableViewCell>>, right: UITableView) {
  left ->> right.designatedBond
}
