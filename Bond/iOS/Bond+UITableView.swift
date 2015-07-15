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
  
  func sectionIndexTitlesForTableView(tableView: UITableView) -> [AnyObject]! {
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
  var section: Int
  init(tableView: UITableView?, section: Int, disableAnimation: Bool = false) {
    self.tableView = tableView
    self.section = section
    super.init()
    
    self.didInsertListener = { [unowned self] a, i in
      if let tableView: UITableView = self.tableView {
        perform(animated: !disableAnimation) {
          tableView.beginUpdates()
          tableView.insertRowsAtIndexPaths(i.map { NSIndexPath(forItem: $0, inSection: self.section) }, withRowAnimation: UITableViewRowAnimation.Automatic)
          tableView.endUpdates()
        }
      }
    }
    
    self.didRemoveListener = { [unowned self] a, i in
      if let tableView = self.tableView {
        perform(animated: !disableAnimation) {
          tableView.beginUpdates()
          tableView.deleteRowsAtIndexPaths(i.map { NSIndexPath(forItem: $0, inSection: self.section) }, withRowAnimation: UITableViewRowAnimation.Automatic)
          tableView.endUpdates()
        }
      }
    }
    
    self.didUpdateListener = { [unowned self] a, i in
      if let tableView = self.tableView {
        perform(animated: !disableAnimation) {
          tableView.beginUpdates()
          tableView.reloadRowsAtIndexPaths(i.map { NSIndexPath(forItem: $0, inSection: self.section) }, withRowAnimation: UITableViewRowAnimation.Automatic)
          tableView.endUpdates()
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
  public weak var nextDataSource: UITableViewDataSource? {
    didSet(newValue) {
      dataSource?.nextDataSource = newValue
    }
  }
  
  public init(tableView: UITableView, disableAnimation: Bool = false) {
    self.disableAnimation = disableAnimation
    self.tableView = tableView
    super.init()
    
    self.willMutateListener = { [weak self] array in
      self?.tableView?.beginUpdates()
    }
    
    self.didMutateListener = { [weak self] array in
      self?.tableView?.endUpdates()
    }
    
    self.didInsertListener = { [weak self] array, i in
      if let s = self {
        if let tableView: UITableView = self?.tableView {
          perform(animated: !disableAnimation) {
            tableView.insertSections(NSIndexSet(array: i), withRowAnimation: UITableViewRowAnimation.Automatic)
            
            for section in sorted(i, <) {
              let sectionBond = UITableViewDataSourceSectionBond<Void>(tableView: tableView, section: section, disableAnimation: disableAnimation)
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
            for section in sorted(i, >) {
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
              let sectionBond = UITableViewDataSourceSectionBond<Void>(tableView: tableView, section: section, disableAnimation: disableAnimation)
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
      if let tableView = self?.tableView {
        tableView.reloadData()
      }
    }
  }
  
  public func bind(dynamic: DynamicArray<UITableViewCell>) {
    bind(DynamicArray([dynamic]))
  }
  
  /**
    if we get re-bound while waiting for our previous array
		to stop mutating, we need to know not to start observing our previous array
  */
  private var bindCount = 0
  
  public override func bind(dynamic: Dynamic<Array<DynamicArray<UITableViewCell>>>, fire: Bool, strongly: Bool) {
    bindCount++
    if let dynamic = dynamic as? DynamicArray<DynamicArray<UITableViewCell>> {
      
      /// reload data now to get the latest into table view
      dataSource = TableViewDynamicArrayDataSource(dynamic: dynamic)
      dataSource?.nextDataSource = self.nextDataSource
      tableView?.dataSource = dataSource
      self.tableView?.reloadData()
      
      let oldBindCount = self.bindCount
      /// wait until array stops mutating before binding super and creating section bonds
      dynamic.doAfterMutating { [weak self] dynamic in
        if let strongSelf = self, tableView = strongSelf.tableView where strongSelf.bindCount == oldBindCount {
          strongSelf.superBind(dynamic, fire: false, strongly: strongly)
          for section in 0..<dynamic.count {
            let sectionBond = UITableViewDataSourceSectionBond<Void>(tableView: tableView, section: section, disableAnimation: strongSelf.disableAnimation)
            let sectionDynamic = dynamic[section]
            sectionDynamic.bindTo(sectionBond)
            strongSelf.sectionBonds.append(sectionBond)
          }
        }
      }
    }
  }
  
  // you can't call `super.` in a closure, so we use this to defer our super-binding until array stops mutating
  final private func superBind(dynamic: Dynamic<Array<DynamicArray<UITableViewCell>>>, fire: Bool, strongly: Bool) {
    super.bind(dynamic, fire: fire, strongly: strongly)
  }
  
  deinit {
    self.unbindAll()
    tableView?.dataSource = nil
    self.dataSource = nil
  }
}

private func perform(#animated: Bool, block: () -> Void) {
  if !animated {
    UIView.performWithoutAnimation(block)
  } else {
    block()
  }
}

public func ->> <T>(left: DynamicArray<UITableViewCell>, right: UITableViewDataSourceBond<T>) {
  right.bind(left)
}
