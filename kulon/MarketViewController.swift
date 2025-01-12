 //
//  SecondViewController.swift
//  kulon
//
//  Created by Артмеий Шлесберг on 19/04/2017.
//  Copyright © 2017 Jufy. All rights reserved.
//

import UIKit
import RxBluetoothKit
import RxSwift
import RxCocoa
import RxDataSources

 
class StoreViewController: BaseViewController, ExpandableButtonDelegate, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var categoriesTableView: UITableView! {
        didSet {
            categoriesTableView.delegate = self
            categoriesTableView.dataSource = self
        }
    }
    @IBOutlet weak var topButton: ExpandableButton!
    @IBOutlet weak var tagInputView: UIView!
    @IBOutlet weak var tagTextField: UITextField! {
        didSet {
            tagTextField.delegate = self
        }
    }
    @IBOutlet weak var tagBottomConstraint: NSLayoutConstraint!

    
    private let bleService = BLEService.shared
    private var blurView: UIVisualEffectView!
    private let marketService = MarketService()
    
    var bag: DisposeBag = DisposeBag()
    var names: [NamedObject & IdiableObject] = [] {
        didSet {
            filteredNames = names
        }
    }
    var filteredNames: [NamedObject & IdiableObject] = []
    var getNamesMethod: Observable<[NamedObject & IdiableObject]>?
    var marketParameter =  MarketParameter()
    var observableParameter = ObservableMarketParameter()
    var artworks: MarketableArtworks!
    
    enum SelectionMode {
        case tag, category, artist, none
    }
    
    var currentSelectionMode = SelectionMode.none
    
    override func viewDidLoad() {
        super.viewDidLoad()
        topButton.delegate = self
        
        //TODO: try to rewrite using rx
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        categoriesTableView.contentInset = UIEdgeInsets(top: 140, left: 0, bottom: 0, right: 0)
        categoriesTableView.tableFooterView = UIView() //hack to remove empty
                
        let dataSource = RxCollectionViewSectionedReloadDataSource<StandardSectionModel<MarketableArtwork>>()
        
        dataSource.configureCell = { ds, cv, ip, item in
            let cell = cv.dequeueReusableCell(withReuseIdentifier: Identifiers.Cell.poshikCell, for: ip) as! PoshikCell
            cell.configure(with: item)
//            self.poshiks.loadNextPageIfNeeded(for: ip)
            return cell
        }
        
        dataSource.supplementaryViewFactory = { [unowned self] ds, cv, kind, ip in
            let view = cv.dequeueReusableSupplementaryView(ofKind: UICollectionElementKindSectionHeader, withReuseIdentifier: "Header", for: ip) as! CollectionHeaderView
            view.configure(with: self.marketParameter.name())
            return view//UICollectionReusableView()
        }

        collectionView.contentInset = UIEdgeInsets(top: 80, left: 0, bottom: 0, right: 0)

        let refreshConrol = UIRefreshControl()
        
        artworks = MarketableArtworksFromAPI(parameter: observableParameter.asObservable())
        RefreshableByRefreshControl(
            origin: artworks.asObservable(),
            updatedOn: refreshConrol)
        .asObservable()
        .catchErrorJustReturn([])
        .map{ [StandardSectionModel(items: $0)] }
        .bind(to: collectionView.rx.items(dataSource: dataSource))
        .disposed(by: bag)
        
        collectionView.rx.modelSelected(MarketableArtwork.self).subscribe(onNext: { [unowned self] in
            self.navigationController?.pushViewController(MarketableArtworkController(marketableArtwork: $0), animated: true)
        }).disposed(by: bag)
    
        collectionView.refreshControl = refreshConrol
        
        topButton.subButtons = [
            categoryButton,
            artistsButton,
            tagButton,
            resetButton
        ]
        blurView = UIVisualEffectView(frame: view.bounds)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupInterface()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        topButton.hideButtons()
    }
    
    let categoryButton = RoundedButton.button(with: #imageLiteral(resourceName: "icon_top_category_red"), highlightIcon: #imageLiteral(resourceName: "icon_top_category_white"),target: self, action: #selector(searchCategories))
    .with(tintColor: UIColor.Kulon.orange)
    let tagButton = RoundedButton.button(with: #imageLiteral(resourceName: "icon_top_tag"), highlightIcon: #imageLiteral(resourceName: "icon_top_tag_selected"), target: self, action: #selector(searchTags))
    .with(tintColor: UIColor.Kulon.orange)
    let resetButton = RoundedButton.button(with: #imageLiteral(resourceName: "icon_top_cancel"), highlightIcon: #imageLiteral(resourceName: "icon_top_tag_selected"), target: self, action: #selector(resetFilters))
        .with(tintColor: UIColor.Kulon.orange)
    let artistsButton = RoundedButton.button(with: #imageLiteral(resourceName: "icon_artist_black"), highlightIcon: #imageLiteral(resourceName: "icon_artist_white"), target: self, action: #selector(searchArtists))
        .with(tintColor: UIColor.Kulon.orange)

    
    func setupInterface(){
        
        navigationController?.isNavigationBarHidden = true
        
    }
    
    func loadNames() {
        names = []
        self.categoriesTableView.reloadData()
        getNamesMethod?.subscribe(onNext: { [unowned self] names in 
            self.names = names
            self.categoriesTableView.reloadData()
        }).disposed(by: bag)
    }
    
    func applyFilterToNames(string: String) {
        if string == "" {
            filteredNames = names
        } else {
            filteredNames = names.filter { $0.name.lowercased().range(of: string.lowercased()) != nil }
        }
        categoriesTableView.reloadData()
    }
    
    func searchTags() {
        statrSearching()
    }
    
    func searchCategories() {
        startCategorySelection()
    }
    
    func searchArtists() {
        startArtistsSelection()
    }
    
    func resetFilters() {
        marketParameter = MarketParameter()
        observableParameter.update(MarketParameter())
        topButton.hideButtons()
    }
    
    private func statrSearching() {
        tagTextField.placeholder = "TAG"
        currentSelectionMode = .tag
        endCategorySelection()
        endArtistsSelection()
        getNamesMethod = marketService.getTags().map { $0.tags }.asObservable()
        loadNames()
        tagButton.highlight(true)
        tagButton.backgroundColor = UIColor.Kulon.orange
    }
    
    private func endSearching() {
        tagButton.highlight(false)
        tagButton.backgroundColor = .white
    }
    
    private func startCategorySelection() {
        tagTextField.placeholder = "CATEGORY"
        currentSelectionMode = .category
        endSearching()
        endArtistsSelection()
        getNamesMethod = marketService.getCategories().map { $0.categories }.asObservable()
        loadNames()
        categoryButton.highlight(true)
        categoryButton.backgroundColor = UIColor.Kulon.orange
    }
    
    private func endCategorySelection() {
        categoryButton.highlight(false)
        categoryButton.backgroundColor = .white
    }
    
    private func startArtistsSelection() {
        tagTextField.placeholder = "ARTIST"
        currentSelectionMode = .artist
        endSearching()
        endCategorySelection()
        getNamesMethod = marketService.getArtists().map { $0.artists }.asObservable()
        loadNames()
        artistsButton.highlight(true)
        artistsButton.backgroundColor = UIColor.Kulon.orange
        
    }
    
    private func endArtistsSelection() {
        artistsButton.highlight(false)
        artistsButton.backgroundColor = .white
    }
    
    func didSelect(_ object: IdiableObject & NamedObject ) {
        if case .category = currentSelectionMode {
            marketParameter.category = object
        }
        if case .tag = currentSelectionMode {
            marketParameter.tag = object
        }
        if case .artist = currentSelectionMode {
            marketParameter.artist = object
        }
        observableParameter.update(marketParameter)
        topButton.hideButtons()
    }

    
    func showArtist(_ artist: Artist) {
        currentSelectionMode = .artist
        marketParameter.artist = artist
        observableParameter.update(marketParameter)
        topButton.hideButtons()
    }
    
    //MARK: - Expandable button delegate
    
    func willExpand(_ button: ExpandableButton) {
        view.insertSubview(blurView, aboveSubview: collectionView)
        UIView.animate(withDuration: 0.3, animations: {
            self.blurView?.effect = UIBlurEffect(style: .extraLight)
        }, completion: { [unowned self] _ in
                self.categoriesTableView.isHidden = false
            switch self.currentSelectionMode {
            case .artist:
                self.startArtistsSelection()
            case .category:
                self.startCategorySelection()
            case .tag, .none:
                self.statrSearching()
            }
            self.tagInputView.isHidden = false
            self.tagTextField.becomeFirstResponder()
        })
    }
    
    func willShrink(_ button: ExpandableButton) {
        endSearching()
        endCategorySelection()
        view.endEditing(true)
        tagInputView.isHidden = true
        categoriesTableView.isHidden = true
        UIView.animate(withDuration: 0.3, animations: {
            self.blurView.effect = nil
            
        },completion: { completed in
            self.blurView.removeFromSuperview()
        })
    }
    
    //MARK: - keyboard events handling
    
    func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            if tagBottomConstraint.constant == -49 {
                tagBottomConstraint.constant += keyboardSize.height
            }
        }
    }
    
    func keyboardWillHide(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            if tagBottomConstraint.constant != -49 {
                tagBottomConstraint.constant -= keyboardSize.height
            }
        }
    }
    
    //MARK: - tableView 
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredNames.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Identifiers.Cell.categoryCell) as! CategoryCell
        cell.configure(with: filteredNames[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        didSelect(filteredNames[indexPath.row])
    }
    
    //MARK: - textField
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
//        marketParameter.tag = textField.text
//        poshiks.update(parameterValue: marketParameter)
        topButton.hideButtons()
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let fieldString = textField.text {
            applyFilterToNames(string: fieldString.replacingCharacters(in: Range(range, in: fieldString)!, with: string))
        }
        return true
    }
    
    
}

