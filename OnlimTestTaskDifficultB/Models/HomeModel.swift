//
//  HomeModel.swift
//  OnlimTestTaskDifficultB
//
//  Created by Kirill Pustovalov on 16.10.2020.
//

import Foundation

struct HomeModel: Codable {
    var banners: [BannerModel]
    var articles: [ArticleModel]
}
