//
//  ZipCompression+cases.swift
//  Feather
//
//  Created by samara on 22.04.2025.
//

import Zip

extension ZipCompression {
	static var allCases: [ZipCompression] {
		return [.NoCompression, .BestSpeed, .DefaultCompression, .BestCompression]
	}
	
	var label: String {
		switch self {
		case .NoCompression: return "无"
		case .BestSpeed: return "速度优先"
		case .DefaultCompression: return "默认"
		case .BestCompression: return "最佳"
		}
	}
}
