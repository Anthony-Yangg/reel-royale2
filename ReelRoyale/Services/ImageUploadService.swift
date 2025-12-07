import Foundation
import UIKit

/// Protocol for image upload operations
protocol ImageUploadServiceProtocol {
    /// Upload an avatar image
    func uploadAvatar(_ image: UIImage, for userId: String) async throws -> String
    
    /// Upload a catch photo
    func uploadCatchPhoto(_ image: UIImage, for catchId: String) async throws -> String
    
    /// Upload a spot image
    func uploadSpotImage(_ image: UIImage, for spotId: String) async throws -> String
    
    /// Delete an image by URL
    func deleteImage(at url: String) async throws
    
    func uploadCommunityPostMedia(_ image: UIImage, for postId: String) async throws -> String
}

/// Supabase Storage implementation for image uploads
final class SupabaseImageUploadService: ImageUploadServiceProtocol {
    private let supabase: SupabaseService
    
    init(supabase: SupabaseService) {
        self.supabase = supabase
    }
    
    func uploadAvatar(_ image: UIImage, for userId: String) async throws -> String {
        let data = try prepareImage(image, maxSize: 512)
        let path = "\(userId)/avatar_\(Date().timeIntervalSince1970).jpg"
        
        return try await supabase.uploadFile(
            bucket: AppConstants.Supabase.Buckets.avatars,
            path: path,
            data: data
        )
    }
    
    func uploadCatchPhoto(_ image: UIImage, for catchId: String) async throws -> String {
        let data = try prepareImage(image, maxSize: 1024)
        let path = "\(catchId)/photo_\(Date().timeIntervalSince1970).jpg"
        
        return try await supabase.uploadFile(
            bucket: AppConstants.Supabase.Buckets.catchPhotos,
            path: path,
            data: data
        )
    }
    
    func uploadSpotImage(_ image: UIImage, for spotId: String) async throws -> String {
        let data = try prepareImage(image, maxSize: 1024)
        let path = "\(spotId)/image_\(Date().timeIntervalSince1970).jpg"
        
        return try await supabase.uploadFile(
            bucket: AppConstants.Supabase.Buckets.spotImages,
            path: path,
            data: data
        )
    }
    
    func deleteImage(at url: String) async throws {
        // Extract bucket and path from URL
        guard let components = extractStorageComponents(from: url) else {
            throw AppError.validationError("Invalid storage URL")
        }
        
        try await supabase.deleteFile(bucket: components.bucket, path: components.path)
    }
    
    func uploadCommunityPostMedia(_ image: UIImage, for postId: String) async throws -> String {
        let data = try prepareImage(image, maxSize: 2048)
        let path = "\(postId)/media_\(UUID().uuidString).jpg"
        
        return try await supabase.uploadFile(
            bucket: AppConstants.Supabase.Buckets.communityPosts,
            path: path,
            data: data
        )
    }
    
    // MARK: - Private Helpers
    
    private func prepareImage(_ image: UIImage, maxSize: CGFloat) throws -> Data {
        // Resize if needed
        let resizedImage = resize(image: image, maxSize: maxSize)
        
        // Compress to JPEG
        guard let data = resizedImage.jpegData(compressionQuality: 0.8) else {
            throw AppError.validationError("Failed to encode image")
        }
        
        // Check size (max 5MB)
        if data.count > 5 * 1024 * 1024 {
            // Try with lower quality
            guard let compressedData = resizedImage.jpegData(compressionQuality: 0.5) else {
                throw AppError.validationError("Image too large")
            }
            return compressedData
        }
        
        return data
    }
    
    private func resize(image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size
        
        guard size.width > maxSize || size.height > maxSize else {
            return image
        }
        
        let ratio = min(maxSize / size.width, maxSize / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? image
    }
    
    private func extractStorageComponents(from url: String) -> (bucket: String, path: String)? {
        // Parse Supabase storage URL to extract bucket and path
        // Format: https://project.supabase.co/storage/v1/object/public/bucket/path
        
        guard let url = URL(string: url),
              let pathComponents = url.pathComponents.split(separator: "public").last else {
            return nil
        }
        
        let components = Array(pathComponents)
        guard components.count >= 2 else { return nil }
        
        let bucket = String(components[0])
        let path = components.dropFirst().joined(separator: "/")
        
        return (bucket, path)
    }
}

