import SwiftUI

struct CommunityView: View {
    @StateObject private var viewModel = CommunityViewModel()
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.feedItems.isEmpty {
                LoadingView(message: "Loading feed...")
            } else if viewModel.feedItems.isEmpty {
                EmptyStateView(
                    icon: "person.3",
                    title: "No Posts Yet",
                    message: "Be the first to share with the community.",
                    actionTitle: "Create a Post"
                ) {
                    appState.communityNavigationPath.append(NavigationDestination.createPost)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.feedItems) { item in
                            FeedItemView(
                                item: item,
                                onLikeTapped: {
                                    Task { await viewModel.toggleLike(for: item) }
                                },
                                onCommentTapped: {
                                    appState.communityNavigationPath.append(NavigationDestination.postDetail(postId: item.post.id))
                                },
                                onFollowTapped: {
                                    Task { await viewModel.toggleFollow(authorId: item.post.userId) }
                                }
                            )
                            .onTapGesture {
                                appState.communityNavigationPath.append(
                                    NavigationDestination.postDetail(postId: item.post.id)
                                )
                            }
                            .onAppear {
                                Task {
                                    await viewModel.loadMoreIfNeeded(currentItem: item)
                                }
                            }
                        }
                        
                        if viewModel.isLoadingMore {
                            ProgressView()
                                .padding()
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Community")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    appState.communityNavigationPath.append(NavigationDestination.createPost)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.seafoam)
                }
            }
        }
        .task {
            await viewModel.loadFeed()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}

#Preview {
    NavigationStack {
        CommunityView()
            .environmentObject(AppState.shared)
    }
}

import PhotosUI

struct CreatePostView: View {
    @StateObject private var viewModel = CreatePostViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Form {
            Section {
                PhotosPicker(
                    selection: $viewModel.photoItems,
                    maxSelectionCount: 5,
                    matching: .images
                ) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .foregroundColor(.oceanBlue)
                        Text(viewModel.selectedImages.isEmpty ? "Add photos" : "Add more photos")
                        Spacer()
                        Text("\(viewModel.selectedImages.count)/5")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                if !viewModel.selectedImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(viewModel.selectedImages.enumerated()), id: \.offset) { index, image in
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 90, height: 90)
                                    .clipped()
                                    .cornerRadius(10)
                                    .overlay(
                                        Button {
                                            viewModel.selectedImages.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.white)
                                                .background(Color.black.opacity(0.6))
                                                .clipShape(Circle())
                                        }
                                        .padding(4),
                                        alignment: .topTrailing
                                    )
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            } header: {
                Text("Photos")
            }
            
            Section {
                TextField("Write a caption", text: $viewModel.caption, axis: .vertical)
                    .lineLimit(3...6)
                TextField("Add a location", text: $viewModel.locationName)
                TextField("Hashtags (comma or space separated)", text: $viewModel.hashtagsText)
            } header: {
                Text("Details")
            }
        }
        .navigationTitle("New Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Share") {
                    Task { await viewModel.submit() }
                }
                .disabled(!viewModel.isValid || viewModel.isSubmitting)
            }
        }
        .overlay {
            if viewModel.isSubmitting {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    ProgressView("Publishing...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onChange(of: viewModel.photoItems) { _, _ in
            Task { await viewModel.loadSelectedPhotos() }
        }
        .onChange(of: viewModel.didFinish) { _, done in
            if done {
                DispatchQueue.main.async {
                    dismiss()
                }
            }
        }
    }
}

struct PostDetailView: View {
    let postId: String
    @StateObject private var viewModel = PostDetailViewModel()
    
    var body: some View {
        Group {
            if let post = viewModel.post {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            FeedItemView(
                                item: post,
                                onLikeTapped: { Task { await viewModel.toggleLike() } },
                                onCommentTapped: {},
                                onFollowTapped: { Task { await viewModel.toggleFollow() } }
                            )
                            
                            if !viewModel.comments.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(viewModel.comments) { comment in
                                        HStack(alignment: .top, spacing: 10) {
                                            UserAvatarView(user: comment.author, size: 32, showCrown: false)
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(comment.author?.username ?? "Unknown")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                Text(comment.comment.text)
                                                    .font(.body)
                                                Text(comment.comment.createdAt.relativeTime)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 80)
                    }
                    
                    HStack {
                        TextField("Add a comment", text: $viewModel.newComment, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            Task { await viewModel.addComment() }
                        } label: {
                            if viewModel.isSubmittingComment {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.seafoam)
                            }
                        }
                        .disabled(viewModel.newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSubmittingComment)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                }
            } else if viewModel.isLoading {
                ProgressView("Loading...")
            } else {
                Text("Post not found.")
            }
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(postId: postId)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

