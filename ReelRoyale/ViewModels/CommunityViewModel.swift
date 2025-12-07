import Foundation
import Combine
import PhotosUI
import SwiftUI
import UIKit

@MainActor
final class CommunityViewModel: ObservableObject {
    @Published var feedItems: [CommunityPostDetails] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var hasMoreItems = true
    
    private let postRepository: CommunityPostRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let followRepository: FollowRepositoryProtocol
    private var currentOffset = 0
    private let pageSize = AppConstants.Feed.pageSize
    private var cancellables = Set<AnyCancellable>()
    
    init(
        postRepository: CommunityPostRepositoryProtocol? = nil,
        userRepository: UserRepositoryProtocol? = nil,
        followRepository: FollowRepositoryProtocol? = nil
    ) {
        self.postRepository = postRepository ?? AppState.shared.communityPostRepository
        self.userRepository = userRepository ?? AppState.shared.userRepository
        self.followRepository = followRepository ?? AppState.shared.followRepository
        setupBindings()
    }
    
    private func setupBindings() {
        NotificationCenter.default.publisher(for: .communityPostCreated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.refresh()
                }
            }
            .store(in: &cancellables)
    }
    
    func loadFeed() async {
        isLoading = true
        currentOffset = 0
        errorMessage = nil
        
        do {
            let posts = try await postRepository.getFeed(limit: pageSize, offset: 0)
            feedItems = try await enrichPosts(posts)
            hasMoreItems = posts.count >= pageSize
            currentOffset = posts.count
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func loadMoreIfNeeded(currentItem: CommunityPostDetails) async {
        guard !isLoadingMore && hasMoreItems else { return }
        let thresholdIndex = feedItems.index(feedItems.endIndex, offsetBy: -5, limitedBy: feedItems.startIndex) ?? feedItems.startIndex
        guard let itemIndex = feedItems.firstIndex(where: { $0.id == currentItem.id }),
              itemIndex >= thresholdIndex else { return }
        await loadMore()
    }
    
    private func loadMore() async {
        isLoadingMore = true
        do {
            let posts = try await postRepository.getFeed(limit: pageSize, offset: currentOffset)
            let enriched = try await enrichPosts(posts)
            feedItems.append(contentsOf: enriched)
            hasMoreItems = posts.count >= pageSize
            currentOffset += posts.count
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingMore = false
    }
    
    func refresh() async {
        await loadFeed()
    }
    
    private func enrichPosts(_ posts: [CommunityPost]) async throws -> [CommunityPostDetails] {
        guard !posts.isEmpty else { return [] }
        let currentUserId = AppState.shared.currentUser?.id ?? ""
        let userIds = Array(Set(posts.map { $0.userId }))
        let users = try await userRepository.getUsers(byIds: userIds)
        let usersDict = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
        let postIds = posts.map { $0.id }
        let likeInfo = try await postRepository.getLikeInfo(for: postIds, currentUserId: currentUserId)
        var followStates: [String: Bool] = [:]
        if !currentUserId.isEmpty {
            for userId in userIds where userId != currentUserId {
                let isFollowing = try? await followRepository.isFollowing(followerId: currentUserId, followingId: userId)
                followStates[userId] = isFollowing ?? false
            }
        }
        return posts.map { post in
            let like = likeInfo[post.id] ?? PostLikeInfo.empty(for: post.id)
            let isFollowing = followStates[post.userId] ?? false
            return CommunityPostDetails(
                post: post,
                author: usersDict[post.userId],
                likeCount: like.totalCount,
                commentCount: 0,
                isLikedByCurrentUser: like.isLikedByCurrentUser,
                isFollowingAuthor: isFollowing
            )
        }
    }
    
    func toggleLike(for postItem: CommunityPostDetails) async {
        guard let userId = AppState.shared.currentUser?.id else { return }
        
        do {
            let isNowLiked = try await postRepository.toggleLike(postId: postItem.post.id, userId: userId)
            if let index = feedItems.firstIndex(where: { $0.id == postItem.id }) {
                let newLikeCount = isNowLiked ? postItem.likeCount + 1 : postItem.likeCount - 1
                feedItems[index] = CommunityPostDetails(
                    post: postItem.post,
                    author: postItem.author,
                    likeCount: max(0, newLikeCount),
                    commentCount: postItem.commentCount,
                    isLikedByCurrentUser: isNowLiked,
                    isFollowingAuthor: postItem.isFollowingAuthor
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func toggleFollow(authorId: String) async {
        guard let userId = AppState.shared.currentUser?.id, authorId != userId else { return }
        do {
            let isFollowing = try await followRepository.toggleFollow(followerId: userId, followingId: authorId)
            for index in feedItems.indices {
                if feedItems[index].post.userId == authorId {
                    feedItems[index] = CommunityPostDetails(
                        post: feedItems[index].post,
                        author: feedItems[index].author,
                        likeCount: feedItems[index].likeCount,
                        commentCount: feedItems[index].commentCount,
                        isLikedByCurrentUser: feedItems[index].isLikedByCurrentUser,
                        isFollowingAuthor: isFollowing
                    )
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class CreatePostViewModel: ObservableObject {
    @Published var caption: String = ""
    @Published var locationName: String = ""
    @Published var hashtagsText: String = ""
    @Published var selectedImages: [UIImage] = []
    @Published var photoItems: [PhotosPickerItem] = []
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var didFinish = false
    
    private let postRepository: CommunityPostRepositoryProtocol
    private let imageUploadService: ImageUploadServiceProtocol
    
    init(
        postRepository: CommunityPostRepositoryProtocol? = nil,
        imageUploadService: ImageUploadServiceProtocol? = nil
    ) {
        self.postRepository = postRepository ?? AppState.shared.communityPostRepository
        self.imageUploadService = imageUploadService ?? AppState.shared.imageUploadService
    }
    
    func loadSelectedPhotos() async {
        var images: [UIImage] = []
        for item in photoItems {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        selectedImages = images
    }
    
    var isValid: Bool {
        !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selectedImages.isEmpty
    }
    
    func submit() async {
        guard let userId = AppState.shared.currentUser?.id else {
            show(message: "You need to be signed in to post.")
            return
        }
        guard isValid else {
            show(message: "Add at least one photo and a caption.")
            return
        }
        
        isSubmitting = true
        defer { isSubmitting = false }
        
        let postId = UUID().uuidString
        do {
            let uploadedURLs = try await uploadMedia(postId: postId)
            let hashtags = hashtagsText
                .replacingOccurrences(of: "#", with: "")
                .split { $0.isWhitespace || $0 == "," }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            let post = CommunityPost(
                id: postId,
                userId: userId,
                mediaURLs: uploadedURLs,
                caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
                locationName: locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : locationName,
                hashtags: hashtags
            )
            
            _ = try await postRepository.createPost(post)
            NotificationCenter.default.post(name: .communityPostCreated, object: nil)
            didFinish = true
        } catch {
            show(message: error.localizedDescription)
        }
    }
    
    private func uploadMedia(postId: String) async throws -> [String] {
        var urls: [String] = []
        for image in selectedImages {
            let url = try await imageUploadService.uploadCommunityPostMedia(image, for: postId)
            urls.append(url)
        }
        return urls
    }
    
    private func show(message: String) {
        errorMessage = message
        showError = true
    }
}

struct CommentWithAuthor: Identifiable, Equatable {
    let comment: CommunityComment
    let author: User?
    var id: String { comment.id }
}

@MainActor
final class PostDetailViewModel: ObservableObject {
    @Published var post: CommunityPostDetails?
    @Published var comments: [CommentWithAuthor] = []
    @Published var newComment: String = ""
    @Published var isLoading = false
    @Published var isSubmittingComment = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    private let postRepository: CommunityPostRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let followRepository: FollowRepositoryProtocol
    
    init(
        postRepository: CommunityPostRepositoryProtocol? = nil,
        userRepository: UserRepositoryProtocol? = nil,
        followRepository: FollowRepositoryProtocol? = nil
    ) {
        self.postRepository = postRepository ?? AppState.shared.communityPostRepository
        self.userRepository = userRepository ?? AppState.shared.userRepository
        self.followRepository = followRepository ?? AppState.shared.followRepository
    }
    
    func load(postId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let postModel = try await postRepository.getPost(by: postId) else {
                show(message: "Post not found.")
                return
            }
            let enriched = try await enrichPosts([postModel])
            post = enriched.first
            try await loadComments(postId: postId)
        } catch {
            show(message: error.localizedDescription)
        }
    }
    
    private func loadComments(postId: String) async throws {
        let postComments = try await postRepository.getComments(for: postId)
        let userIds = Array(Set(postComments.map { $0.userId }))
        let users = try await userRepository.getUsers(byIds: userIds)
        let dict = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
        comments = postComments.map { CommentWithAuthor(comment: $0, author: dict[$0.userId]) }
    }
    
    private func enrichPosts(_ posts: [CommunityPost]) async throws -> [CommunityPostDetails] {
        guard !posts.isEmpty else { return [] }
        let currentUserId = AppState.shared.currentUser?.id ?? ""
        let userIds = Array(Set(posts.map { $0.userId }))
        let users = try await userRepository.getUsers(byIds: userIds)
        let usersDict = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
        let postIds = posts.map { $0.id }
        let likeInfo = try await postRepository.getLikeInfo(for: postIds, currentUserId: currentUserId)
        var followStates: [String: Bool] = [:]
        if !currentUserId.isEmpty {
            for userId in userIds where userId != currentUserId {
                let isFollowing = try? await followRepository.isFollowing(followerId: currentUserId, followingId: userId)
                followStates[userId] = isFollowing ?? false
            }
        }
        return posts.map { post in
            let like = likeInfo[post.id] ?? PostLikeInfo.empty(for: post.id)
            let isFollowing = followStates[post.userId] ?? false
            return CommunityPostDetails(
                post: post,
                author: usersDict[post.userId],
                likeCount: like.totalCount,
                commentCount: 0,
                isLikedByCurrentUser: like.isLikedByCurrentUser,
                isFollowingAuthor: isFollowing
            )
        }
    }
    
    func toggleLike() async {
        guard let post else { return }
        guard let userId = AppState.shared.currentUser?.id else { return }
        do {
            let isNowLiked = try await postRepository.toggleLike(postId: post.post.id, userId: userId)
            let newLikeCount = isNowLiked ? post.likeCount + 1 : post.likeCount - 1
            self.post = CommunityPostDetails(
                post: post.post,
                author: post.author,
                likeCount: max(0, newLikeCount),
                commentCount: post.commentCount,
                isLikedByCurrentUser: isNowLiked,
                isFollowingAuthor: post.isFollowingAuthor
            )
        } catch {
            show(message: error.localizedDescription)
        }
    }
    
    func toggleFollow() async {
        guard let post else { return }
        guard let userId = AppState.shared.currentUser?.id, userId != post.post.userId else { return }
        do {
            let isFollowing = try await followRepository.toggleFollow(followerId: userId, followingId: post.post.userId)
            self.post = CommunityPostDetails(
                post: post.post,
                author: post.author,
                likeCount: post.likeCount,
                commentCount: post.commentCount,
                isLikedByCurrentUser: post.isLikedByCurrentUser,
                isFollowingAuthor: isFollowing
            )
        } catch {
            show(message: error.localizedDescription)
        }
    }
    
    func addComment() async {
        guard let userId = AppState.shared.currentUser?.id else { return }
        guard let post else { return }
        let trimmed = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSubmittingComment = true
        defer { isSubmittingComment = false }
        do {
            let comment = CommunityComment(postId: post.post.id, userId: userId, text: trimmed)
            let saved = try await postRepository.addComment(comment)
            let author = try await userRepository.getUser(byId: userId)
            comments.append(CommentWithAuthor(comment: saved, author: author))
            newComment = ""
            self.post = CommunityPostDetails(
                post: post.post,
                author: post.author,
                likeCount: post.likeCount,
                commentCount: post.commentCount + 1,
                isLikedByCurrentUser: post.isLikedByCurrentUser,
                isFollowingAuthor: post.isFollowingAuthor
            )
        } catch {
            show(message: error.localizedDescription)
        }
    }
    
    private func show(message: String) {
        errorMessage = message
        showError = true
    }
}

