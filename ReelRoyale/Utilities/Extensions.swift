import Foundation
import SwiftUI
import CoreLocation

// MARK: - Date Extensions

extension Date {
    /// Returns a relative time string (e.g., "2 hours ago")
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Returns a formatted date string
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
    
    /// Returns a formatted date and time string
    var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    /// ISO8601 string for API calls
    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
}

// MARK: - String Extensions

extension String {
    /// Validates email format
    var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: self)
    }
    
    /// Checks if string is empty or whitespace only
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Truncates string to specified length
    func truncated(to length: Int, trailing: String = "...") -> String {
        if count <= length {
            return self
        }
        return String(prefix(length)) + trailing
    }
}

// MARK: - Double Extensions

extension Double {
    /// Formats as distance string
    var formattedDistance: String {
        if self < 1000 {
            return "\(Int(self)) m"
        } else {
            return String(format: "%.1f km", self / 1000)
        }
    }
    
    /// Formats as size with unit
    func formattedSize(unit: String) -> String {
        if self == floor(self) {
            return "\(Int(self)) \(unit)"
        }
        return String(format: "%.1f %@", self, unit)
    }
}

// MARK: - CLLocationCoordinate2D Extensions

extension CLLocationCoordinate2D {
    /// Distance to another coordinate in meters
    func distance(to other: CLLocationCoordinate2D) -> Double {
        let thisLocation = CLLocation(latitude: latitude, longitude: longitude)
        let otherLocation = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return thisLocation.distance(from: otherLocation)
    }
    
    /// Formatted coordinates string
    var formatted: String {
        String(format: "%.4f, %.4f", latitude, longitude)
    }
}

// MARK: - View Extensions

extension View {
    /// Applies corner radius to specific corners
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    
    /// Conditional view modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Hide view conditionally
    @ViewBuilder
    func hidden(_ isHidden: Bool) -> some View {
        if isHidden {
            self.hidden()
        } else {
            self
        }
    }
    
    /// Standard card styling
    func cardStyle(backgroundColor: Color = .white) -> some View {
        self
            .background(backgroundColor)
            .cornerRadius(AppConstants.UI.cornerRadius)
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

/// Custom shape for specific corner radius
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Image Extensions

extension Image {
    /// Scales image to fit within specified size
    func scaledToFit(size: CGFloat) -> some View {
        self
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
    
    /// Scales image to fill specified size
    func scaledToFill(size: CGFloat) -> some View {
        self
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipped()
    }
}

// MARK: - Array Extensions

extension Array where Element: Identifiable {
    /// Returns element with matching ID
    func first(withId id: Element.ID) -> Element? {
        first { $0.id == id }
    }
    
    /// Returns index of element with matching ID
    func firstIndex(withId id: Element.ID) -> Int? {
        firstIndex { $0.id == id }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let userDidLogin = Notification.Name("userDidLogin")
    static let userDidLogout = Notification.Name("userDidLogout")
    static let catchCreated = Notification.Name("catchCreated")
    static let spotUpdated = Notification.Name("spotUpdated")
    static let kingDethroned = Notification.Name("kingDethroned")
}

// MARK: - Error Handling

enum AppError: LocalizedError {
    case networkError(String)
    case authError(String)
    case validationError(String)
    case notFound(String)
    case unauthorized
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .authError(let message):
            return "Authentication error: \(message)"
        case .validationError(let message):
            return "Validation error: \(message)"
        case .notFound(let resource):
            return "\(resource) not found"
        case .unauthorized:
            return "You are not authorized to perform this action"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

