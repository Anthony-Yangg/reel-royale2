import Foundation
import Supabase

/// Core Supabase client wrapper
final class SupabaseService {
    /// The Supabase client instance
    let client: SupabaseClient
    
    init() {
        guard let url = URL(string: AppConstants.Supabase.projectURL) else {
            fatalError("Invalid Supabase URL. Please update AppConstants.Supabase.projectURL")
        }
        
        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: AppConstants.Supabase.anonKey
        )
    }
    
    /// Access to the database
    var database: PostgrestClient {
        client.database
    }
    
    /// Access to auth
    var auth: AuthClient {
        client.auth
    }
    
    /// Access to storage
    var storage: SupabaseStorageClient {
        client.storage
    }
    
    /// Get current session
    var currentSession: Session? {
        get async {
            try? await client.auth.session
        }
    }
    
    /// Get current user ID
    var currentUserId: String? {
        get async {
            await currentSession?.user.id.uuidString
        }
    }
}

// MARK: - Database Helpers

extension SupabaseService {
    /// Fetch all rows from a table
    func fetchAll<T: Decodable>(from table: String) async throws -> [T] {
        try await database
            .from(table)
            .select()
            .execute()
            .value
    }
    
    /// Fetch single row by ID
    func fetchById<T: Decodable>(from table: String, id: String) async throws -> T? {
        let results: [T] = try await database
            .from(table)
            .select()
            .eq("id", value: id)
            .execute()
            .value
        return results.first
    }
    
    /// Insert a row
    func insert<T: Encodable>(_ item: T, into table: String) async throws {
        try await database
            .from(table)
            .insert(item)
            .execute()
    }
    
    /// Insert and return the inserted row
    func insertAndReturn<T: Codable>(_ item: T, into table: String) async throws -> T {
        try await database
            .from(table)
            .insert(item)
            .select()
            .single()
            .execute()
            .value
    }
    
    /// Update a row by ID
    func update<T: Encodable>(_ item: T, in table: String, id: String) async throws {
        try await database
            .from(table)
            .update(item)
            .eq("id", value: id)
            .execute()
    }
    
    /// Delete a row by ID
    func delete(from table: String, id: String) async throws {
        try await database
            .from(table)
            .delete()
            .eq("id", value: id)
            .execute()
    }
}

// MARK: - Storage Helpers

extension SupabaseService {
    /// Upload a file to storage
    func uploadFile(
        bucket: String,
        path: String,
        data: Data,
        contentType: String = "image/jpeg"
    ) async throws -> String {
        try await storage
            .from(bucket)
            .upload(
                path: path,
                file: data,
                options: FileOptions(contentType: contentType)
            )
        
        // Return the public URL
        let publicURL = try storage.from(bucket).getPublicURL(path: path)
        return publicURL.absoluteString
    }
    
    /// Delete a file from storage
    func deleteFile(bucket: String, path: String) async throws {
        try await storage
            .from(bucket)
            .remove(paths: [path])
    }
    
    /// Get public URL for a file
    func getPublicURL(bucket: String, path: String) throws -> URL {
        try storage.from(bucket).getPublicURL(path: path)
    }
}

