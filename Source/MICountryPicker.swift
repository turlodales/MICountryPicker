//
//  MICountryPicker.swift
//  MICountryPicker
//
//  Created by Ibrahim, Mustafa on 1/24/16.
//  Copyright © 2016 Mustafa Ibrahim. All rights reserved.
//

import UIKit

class MICountry: NSObject {
    let name: String
    let code: String
    var section: Int?
    let dialCode: String!
    
    init(name: String, code: String, dialCode: String = " - ") {
        self.name = name
        self.code = code
        self.dialCode = dialCode
    }
}

struct Section {
    var countries: [MICountry] = []
    
    mutating func addCountry(country: MICountry) {
        countries.append(country)
    }
}

@objc public protocol MICountryPickerDelegate: class {
    func countryPicker(picker: MICountryPicker, didSelectCountryWithName name: String, code: String)
    optional func countryPicker(picker: MICountryPicker, didSelectCountryWithName name: String, code: String, dialCode: String)
}

public class MICountryPicker: UITableViewController {
    
    public var customCountriesCode: [String]?
    
    private lazy var CallingCodes = { () -> [[String: String]] in
        guard let path = NSBundle.mainBundle().pathForResource("CallingCodes", ofType: "plist") else { return [] }
        return NSArray(contentsOfFile: path) as! [[String: String]]
    }()
    private var searchController: UISearchController!
    private var filteredList = [MICountry]()
    private var unsourtedCountries : [MICountry] {
        let locale = NSLocale.currentLocale()
        var unsourtedCountries = [MICountry]()
        let countriesCodes = customCountriesCode == nil ? NSLocale.ISOCountryCodes() : customCountriesCode!
        
        for countryCode in countriesCodes {
            let displayName = locale.displayNameForKey(NSLocaleCountryCode, value: countryCode)
            let countryData = CallingCodes.filter { $0["code"] == countryCode }
            let country: MICountry

            if countryData.count > 0, let dialCode = countryData[0]["dial_code"] {
                country = MICountry(name: displayName!, code: countryCode, dialCode: dialCode)
            } else {
                country = MICountry(name: displayName!, code: countryCode)
            }
            unsourtedCountries.append(country)
        }
        
        return unsourtedCountries
    }
    
    private var _sections: [Section]?
    private var sections: [Section] {
        
        if _sections != nil {
            return _sections!
        }
        
        let countries: [MICountry] = unsourtedCountries.map { country in
            let country = MICountry(name: country.name, code: country.code, dialCode: country.dialCode)
            country.section = collation.sectionForObject(country, collationStringSelector: Selector("name"))
            return country
        }
        
        // create empty sections
        var sections = [Section]()
        for _ in 0..<self.collation.sectionIndexTitles.count {
            sections.append(Section())
        }
        
        // put each country in a section
        for country in countries {
            sections[country.section!].addCountry(country)
        }
        
        // sort each section
        for section in sections {
            var s = section
            s.countries = collation.sortedArrayFromArray(section.countries, collationStringSelector: Selector("name")) as! [MICountry]
        }
        
        _sections = sections
        
        return _sections!
    }
    private let collation = UILocalizedIndexedCollation.currentCollation()
        as UILocalizedIndexedCollation
    public weak var delegate: MICountryPickerDelegate?
    public var didSelectCountryClosure: ((String, String) -> ())?
    public var didSelectCountryWithCallingCodeClosure: ((String, String, String) -> ())?
    public var showCallingCodes = false

    convenience public init(completionHandler: ((String, String) -> ())) {
        self.init()
        self.didSelectCountryClosure = completionHandler
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "UITableViewCell")
        createSearchBar()
        tableView.reloadData()
        
        definesPresentationContext = true
    }
    
    // MARK: Methods
    
    private func createSearchBar() {
        if self.tableView.tableHeaderView == nil {
            searchController = UISearchController(searchResultsController: nil)
            searchController.searchResultsUpdater = self
            searchController.dimsBackgroundDuringPresentation = false
            tableView.tableHeaderView = searchController.searchBar
        }
    }
    
    private func filter(searchText: String) -> [MICountry] {
        filteredList.removeAll()
        
        sections.forEach { (section) -> () in
            section.countries.forEach({ (country) -> () in
                if country.name.characters.count >= searchText.characters.count {
                    let result = country.name.compare(searchText, options: [.CaseInsensitiveSearch, .DiacriticInsensitiveSearch], range: searchText.startIndex ..< searchText.endIndex)
                    if result == .OrderedSame {
                        filteredList.append(country)
                    }
                }
            })
        }
        
        return filteredList
    }
}

// MARK: - Table view data source

extension MICountryPicker {
    
    override public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        if searchController.searchBar.isFirstResponder() {
            return 1
        }
        return sections.count
    }
    
    override public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if searchController.searchBar.isFirstResponder() {
            return filteredList.count
        }
        return sections[section].countries.count
    }
    
    override public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        var tempCell: UITableViewCell? = tableView.dequeueReusableCellWithIdentifier("UITableViewCell")
        
        if tempCell == nil {
            tempCell = UITableViewCell(style: .Default, reuseIdentifier: "UITableViewCell")
        }
        
        let cell: UITableViewCell! = tempCell
        
        let country: MICountry!
        if searchController.searchBar.isFirstResponder() {
            country = filteredList[indexPath.row]
        } else {
            country = sections[indexPath.section].countries[indexPath.row]
            
        }

        if showCallingCodes {
            cell.textLabel?.text = country.name + " (" + country.dialCode! + ")"
        } else {
            cell.textLabel?.text = country.name
        }

        let bundle = "assets.bundle/"
        cell.imageView!.image = UIImage(named: bundle + country.code.lowercaseString + ".png", inBundle: NSBundle(forClass: MICountryPicker.self), compatibleWithTraitCollection: nil)
        return cell
    }
    
    override public func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if !sections[section].countries.isEmpty {
            return self.collation.sectionTitles[section] as String
        }
        return ""
    }
    
    override public func sectionIndexTitlesForTableView(tableView: UITableView) -> [String]? {
        return collation.sectionIndexTitles
    }
    
    override public func tableView(tableView: UITableView,
        sectionForSectionIndexTitle title: String,
        atIndex index: Int)
        -> Int {
            return collation.sectionForSectionIndexTitleAtIndex(index)
    }
}

// MARK: - Table view delegate

extension MICountryPicker {
    
    override public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        let country: MICountry!
        if searchController.searchBar.isFirstResponder() {
            country = filteredList[indexPath.row]
        } else {
            country = sections[indexPath.section].countries[indexPath.row]
            
        }
        delegate?.countryPicker(self, didSelectCountryWithName: country.name, code: country.code)
        delegate?.countryPicker?(self, didSelectCountryWithName: country.name, code: country.code, dialCode: country.dialCode)
        didSelectCountryClosure?(country.name, country.code)
        didSelectCountryWithCallingCodeClosure?(country.name, country.code, country.dialCode)
    }
}

// MARK: - UISearchDisplayDelegate

extension MICountryPicker: UISearchResultsUpdating {
    
    public func updateSearchResultsForSearchController(searchController: UISearchController) {
        filter(searchController.searchBar.text!)
        tableView.reloadData()
    }
}
