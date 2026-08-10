//
//  FetchService.swift
//  Loader
//
//  Created by samara on 14.03.2025.
//

import Foundation

// MARK: - Class
public class NBFetchService {
	
	public enum NBFetchServiceError: Error, LocalizedError {
		case invalidURL
		case networkError(Error)
		case noData
		case parsingError(Any)
		
		public var errorDescription: String? {
			switch self {
			case .invalidURL:
				return "链接无效。"
			case .networkError(let error):
				return "Network error: \(error.localizedDescription)"
			case .noData:
				return "未接收到数据。"
			case .parsingError(let error):
				return "解析数据失败：\(error)"
			}
		}
	}
	
	public init() {}
}

// MARK: - Class extension: fetch
extension NBFetchService {
	public func fetch<T: Decodable>(
		from urlString: String,
		completion: @escaping (Result<T, Error>) -> Void
	) {
		guard let url = URL(string: urlString) else {
			completion(.failure(NBFetchServiceError.invalidURL))
			return
		}
		
		fetch(from: url, completion: completion)
	}
	
	public func fetch<T: Decodable>(
		from url: URL,
		completion: @escaping (Result<T, Error>) -> Void
	) {
		DispatchQueue.global(qos: .userInitiated).async {
			let task = URLSession.shared.dataTask(with: url) { data, response, error in
				if let error = error {
					completion(.failure(NBFetchServiceError.networkError(error)))
					return
				}
				
				guard let data = data else {
					completion(.failure(NBFetchServiceError.noData))
					return
				}
				
				do {
					let decoder = JSONDecoder()
					let decodedData = try decoder.decode(T.self, from: data)
					completion(.success(decodedData))
				} catch let decodingError as DecodingError {
					if case .dataCorrupted(let context) = decodingError {
						
						if let underlyingError = context.underlyingError as NSError? {
							
                            if let debugDesc = underlyingError.userInfo["NSDebugDescription"] {
                                print(debugDesc)
                                completion(.failure(NBFetchServiceError.parsingError(debugDesc)))
                            } else {
                                print(decodingError)
                                completion(.failure(NBFetchServiceError.parsingError(decodingError)))
                            }
						}
					}
					
				} catch {
                    print(error)
					completion(.failure(NBFetchServiceError.parsingError(error)))
				}
			}
			
			task.resume()
		}
	}
}
