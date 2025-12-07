import Foundation
import Combine

/// ViewModel for Community feed screen
@MainActor
final class CommunityViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var feedItems: [CatchWithDetails] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var hasMoreItems = true
    
    // MARK: - Private Properties
    
    private let catchRepository: CatchRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let spotRepository: SpotRepositoryProtocol
    private let likeRepository: LikeRepositoryProtocol
    private var currentOffset = 0
    private let pageSize = 20
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        catchRepository: CatchRepositoryProtocol? = nil,
        userRepository: UserRepositoryProtocol? = nil,
        spotRepository: SpotRepositoryProtocol? = nil,
        likeRepository: LikeRepositoryProtocol? = nil
    ) {
        self.catchRepository = catchRepository ?? AppState.shared.catchRepository
        self.userRepository = userRepository ?? AppState.shared.userRepository
        self.spotRepository = spotRepository ?? AppState.shared.spotRepository
        self.likeRepository = likeRepository ?? AppState.shared.likeRepository
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Listen for new catches
        NotificationCenter.default.publisher(for: .catchCreated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.refresh()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    
    func loadFeed() async {
        isLoading = true
        currentOffset = 0
        errorMessage = nil
        
        do {
            let catches = try await catchRepository.getRecentPublicCatches(
                limit: pageSize,
                offset: 0
            )
            
            feedItems = try await enrichCatches(catches)
            hasMoreItems = catches.count >= pageSize
            currentOffset = catches.count
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func loadMoreIfNeeded(currentItem: CatchWithDetails) async {
        guard !isLoadingMore && hasMoreItems else { return }
        
        // Load more when reaching last 5 items
        let thresholdIndex = feedItems.index(feedItems.endIndex, offsetBy: -5)
        guard let itemIndex = feedItems.firstIndex(where: { $0.id == currentItem.id }),
              itemIndex >= thresholdIndex else { return }
        
        await loadMore()
    }
    
    private func loadMore() async {
        isLoadingMore = true
        
        do {
            let catches = try await catchRepository.getRecentPublicCatches(
                limit: pageSize,
                offset: currentOffset
            )
            
            let enrichedCatches = try await enrichCatches(catches)
            feedItems.append(contentsOf: enrichedCatches)
            hasMoreItems = catches.count >= pageSize
            currentOffset += catches.count
        } catch {
            print("Failed to load more: \(error)")
        }
        
        isLoadingMore = false
    }
    
    func refresh() async {
        await loadFeed()
    }
    
    // MARK: - Enrich Data
    
    private func enrichCatches(_ catches: [FishCatch]) async throws -> [CatchWithDetails] {
        guard !catches.isEmpty else { return [] }
        
        let currentUserId = AppState.shared.currentUser?.id ?? ""
        
        // Get unique user IDs
        let userIds = Array(Set(catches.map { $0.userId }))
        let users = try await userRepository.getUsers(byIds: userIds)
        let usersDict = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
        
        // Get unique spot IDs (skip nil)
        let spotIds = Array(Set(catches.compactMap { $0.spotId }))
        var spotsDict: [String: Spot] = [:]
        for spotId in spotIds {
            if let spot = try await spotRepository.getSpot(byId: spotId) {
                spotsDict[spotId] = spot
            }
        }
        
        // Get like info
        let catchIds = catches.map { $0.id }
        let likeInfo = try await likeRepository.getLikeInfo(for: catchIds, currentUserId: currentUserId)
        
        // Build enriched items
        return catches.map { fishCatch in
            let spot = fishCatch.spotId.flatMap { spotsDict[$0] }
            let like = likeInfo[fishCatch.id] ?? LikeInfo.empty(for: fishCatch.id)
            
            return CatchWithDetails(
                fishCatch: fishCatch,
                user: usersDict[fishCatch.userId],
                spot: spot,
                likeCount: like.totalCount,
                isLikedByCurrentUser: like.isLikedByCurrentUser,
                isCurrentKing: spot?.currentKingUserId == fishCatch.userId
            )
        }
    }
    
    // MARK: - Actions
    
    func toggleLike(for catchItem: CatchWithDetails) async {
        guard let userId = AppState.shared.currentUser?.id else { return }
        
        do {
            let isNowLiked = try await likeRepository.toggleLike(
                catchId: catchItem.fishCatch.id,
                userId: userId
            )
            
            // Update local state
            if let index = feedItems.firstIndex(where: { $0.id == catchItem.id }) {
                let newLikeCount = isNowLiked ? catchItem.likeCount + 1 : catchItem.likeCount - 1
                feedItems[index] = CatchWithDetails(
                    fishCatch: catchItem.fishCatch,
                    user: catchItem.user,
                    spot: catchItem.spot,
                    likeCount: max(0, newLikeCount),
                    isLikedByCurrentUser: isNowLiked,
                    isCurrentKing: catchItem.isCurrentKing
                )
            }
        } catch {
            print("Failed to toggle like: \(error)")
        }
    }
}

