//
//  HomeViewController.swift
//  OnlimTestTaskDifficultB
//
//  Created by Kirill Pustovalov on 16.10.2020.
//

import UIKit

class HomeViewController: UIViewController {
    var homeModel: HomeModel? {
        didSet {
            guard oldValue?.banners != homeModel?.banners else { return }
            activeBannerCells = homeModel?.banners.filter { $0.active == true }
        }
    }
    var activeBannerCells: [BannerModel]?
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        return scrollView
    }()
    private let bannersCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 0
        
        let bannersCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        bannersCollectionView.translatesAutoresizingMaskIntoConstraints = false
        bannersCollectionView.isPagingEnabled = true
        bannersCollectionView.backgroundColor = .clear
        bannersCollectionView.showsHorizontalScrollIndicator = false
        
        return bannersCollectionView
    }()
    let articleTableView: IntrinsicTableView = {
        let articleTableView = IntrinsicTableView(frame: .zero, style: .insetGrouped)
        articleTableView.backgroundColor = .secondarySystemGroupedBackground
        articleTableView.isScrollEnabled = false
        
        articleTableView.translatesAutoresizingMaskIntoConstraints = false
        return articleTableView
    }()
    private var previousIndexPathAtCenter: IndexPath?

    private var currentIndexPath: IndexPath? {
        let center = view.convert(bannersCollectionView.center, to: bannersCollectionView)
        return bannersCollectionView.indexPathForItem(at: center)
    }
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)

        if let indexAtCenter = currentIndexPath {
            previousIndexPathAtCenter = indexAtCenter
        }
        
        bannersCollectionView.collectionViewLayout.invalidateLayout()
    }
    // MARK: - ViewLifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()
        firstLaunchHandler()
        
        setupNavigationBar()
        setupViews()
        setupAutoLayout()
    }
    override func viewDidLayoutSubviews() {
        let contentRect: CGRect = scrollView.subviews.reduce(into: .zero) { rect, view in
            rect = rect.union(view.frame)
        }
        scrollView.contentSize = contentRect.size
    }
    func firstLaunchHandler() {
        let flag = "hasBeenLaunchedBeforeFlag"
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: flag)
        
        let coreDataService = CoreDataService()
        if isFirstLaunch {
            guard let url = URL(string: "https://onlym.ru/api_test/test.json") else { return }
            let dataFetcherService = DataFetcherService()
            
            dataFetcherService.fetchDataFromURl(url: url) { [self] (response: HomeModel?, data: Data?) in
                if let response = response {
                    homeModel = response
                    guard let data = data else { return }
                    
                    DispatchQueue.main.async {
                        coreDataService.saveHomeModelData(data: data as NSData)
                    }
                    
                    UserDefaults.standard.set(true, forKey: flag)
                    UserDefaults.standard.synchronize()
                    
                    DispatchQueue.main.async {
                        bannersCollectionView.reloadData()
                        articleTableView.reloadData()
                    }
                } else {
                    let alert = UIAlertController(title: "Что-то сломалось", message: "Произошла ошибка. Проверьте, есть ли подключение к интернету", preferredStyle: .alert)
                    let retryAction = UIAlertAction(title: "Попробовать еще раз", style: .default) { _ in
                        firstLaunchHandler()
                    }
                    let createByYourselfAction = UIAlertAction(title: "Отменить скачивание", style: .default) { _ in
                        UserDefaults.standard.set(true, forKey: flag)
                        UserDefaults.standard.synchronize()
                    }
                    let cancelAction = UIAlertAction(title: "Выйти", style: .destructive) { _ in
                        exit(0);
                    }
                    
                    alert.addAction(retryAction)
                    alert.addAction(createByYourselfAction)
                    alert.addAction(cancelAction)
                    
                    DispatchQueue.main.async {
                        self.present(alert, animated: true)
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                let data = coreDataService.fetchHomeModelData()
                
                let jsonDecoder = JSONDecoder()
                jsonDecoder.dateDecodingStrategy = .iso8601
                
                let coreDataHomeModel = try? jsonDecoder.decode(HomeModel.self, from: data! as Data)
                guard coreDataHomeModel != nil else { return }
                self.homeModel = coreDataHomeModel
                
                self.bannersCollectionView.reloadData()
                self.articleTableView.reloadData()
            }
        }
    }
    func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(settingsNavigationBarTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNavigationBarButtonTapped))
        title = "Главная"
    }
    func setupViews() {
        view.addSubview(scrollView)
        scrollView.addSubview(bannersCollectionView)
        
        bannersCollectionView.delegate = self
        bannersCollectionView.dataSource = self
        bannersCollectionView.register(BannerCollectionViewCell.self, forCellWithReuseIdentifier: "bannersCollectionViewCell")
        
        scrollView.addSubview(articleTableView)
        articleTableView.delegate = self
        articleTableView.dataSource = self
        
        articleTableView.register(ArticleTableViewCell.self, forCellReuseIdentifier: "articlesTableViewCell")
    }
    func setupAutoLayout() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scrollView.widthAnchor.constraint(equalTo: view.widthAnchor),
        ])
        NSLayoutConstraint.activate([
            bannersCollectionView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 10),
            bannersCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            bannersCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            bannersCollectionView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.25)
        ])
        NSLayoutConstraint.activate([
            articleTableView.topAnchor.constraint(equalTo: bannersCollectionView.bottomAnchor, constant: 10),
            articleTableView.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])
    }
    // MARK: - Navigation
    @objc func settingsNavigationBarTapped() {
        let settingsViewController = BannerSettingsViewController()
        settingsViewController.modalPresentationStyle = .formSheet
        
        if self.homeModel == nil { self.homeModel = HomeModel(banners: [], articles: []) }
        guard let banners = homeModel?.banners else { return }
        
        settingsViewController.setData(banners: banners)
        navigationController?.present(UINavigationController(rootViewController: settingsViewController), animated: true)
        
        settingsViewController.onSaveClosure = { banners in
            guard self.homeModel?.banners != banners else { return }
            
            self.homeModel?.banners = banners
            self.bannersCollectionView.reloadData()
            
            DispatchQueue.main.async {
                let coreDataService = CoreDataService()
                
                let encoder = JSONEncoder()
                guard let data = try? encoder.encode(self.homeModel) else { return }
                coreDataService.saveHomeModelData(data: NSData(data: data))
            }
        }
    }
    @objc func addNavigationBarButtonTapped() {
        let newBannerViewController = NewBannerViewController()
        newBannerViewController.modalPresentationStyle = .formSheet
        navigationController?.present(UINavigationController(rootViewController: newBannerViewController), animated: true)
        
        newBannerViewController.onSaveClosure = { banner, index in
            self.homeModel?.banners.insert(banner, at: index)
            self.bannersCollectionView.reloadData()
            
            DispatchQueue.main.async {
                let coreDataService = CoreDataService()
                
                let encoder = JSONEncoder()
                guard let data = try? encoder.encode(self.homeModel) else { return }
                coreDataService.saveHomeModelData(data: NSData(data: data))
            }
        }
    }
}
// MARK: - UICollectionViewExtensions
extension HomeViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let activeBannerCells = activeBannerCells else { return 0 }
        return activeBannerCells.count
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "bannersCollectionViewCell", for: indexPath as IndexPath) as! BannerCollectionViewCell
        guard let banner = activeBannerCells?[indexPath.row] else { return UICollectionViewCell() }
        
        cell.setupCellData(banner: banner)
        return cell
    }
}
extension HomeViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, targetContentOffsetForProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        guard let oldCenter = previousIndexPathAtCenter else {
            return proposedContentOffset
        }
        let attrs =  collectionView.layoutAttributesForItem(at: oldCenter)
        let newOriginForOldIndex = attrs?.frame.origin
        
        return newOriginForOldIndex ?? proposedContentOffset
    }
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: bannersCollectionView.bounds.width - 10, height: bannersCollectionView.bounds.height)
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        10
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
    }
}
// MARK: - UITableViewExtensions
extension HomeViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let homeModel = homeModel else { return 0 }
        return homeModel.articles.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "articlesTableViewCell", for: indexPath as IndexPath) as! ArticleTableViewCell
        guard let article = homeModel?.articles[indexPath.row] else { return UITableViewCell() }
        cell.setupCellData(article: article)
        
        return cell
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: tableView.frame.width, height: 50))
        
        let label = UILabel()
        label.font = label.font.withSize(30)
        
        label.frame = CGRect.init(x: 5, y: 5, width: headerView.frame.width - 10, height: headerView.frame.height - 10)
        label.text = "Все статьи"
        headerView.addSubview(label)
        
        return headerView
    }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 250
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let articleDetailViewController = ArticleDetailViewController()
        
        guard let article = homeModel?.articles[indexPath.row] else { return}
        
        articleDetailViewController.setData(article: article, articles: homeModel!.articles, indexPath: indexPath)
        
        navigationController?.pushViewController(articleDetailViewController, animated: true)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
