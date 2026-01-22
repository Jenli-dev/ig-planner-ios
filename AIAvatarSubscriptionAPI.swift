import Foundation

// MARK: - Response Models

struct AIAvatarSubscriptionStatus: Decodable {
    let ok: Bool
    let is_active: Bool
    let plan_type: String?  // "weekly" | "monthly" | "yearly"
    let credits_remaining: Int
    let daily_credits_used: Int
    let daily_limit: Int
    let can_generate_avatar_batch: Bool
    let expires_at: String?  // ISO date string
    let reset_at: String?     // ISO date string
}

struct AIAvatarCreditsCheck: Decodable {
    let ok: Bool
    let can_proceed: Bool
    let credits_needed: Int
    let credits_remaining: Int
    let daily_limit_reached: Bool
    let reason: String?
}

struct AIAvatarCreditsBalance: Decodable {
    let ok: Bool
    let credits_remaining: Int
    let daily_credits_used: Int
    let daily_limit: Int
    let is_active: Bool
}

struct AIAvatarSubscriptionActivate: Decodable {
    let ok: Bool
    let subscription: AIAvatarSubscriptionData
}

struct AIAvatarSubscriptionData: Decodable {
    let user_id: String
    let plan_type: String
    let activated_at: String
    let expires_at: String
    let credits_period: Int
    let daily_limit: Int
    let avatar_batch_included: Bool
}

// MARK: - API Client

enum AIAvatarSubscriptionAPI {
    
    // MARK: - Subscription Status
    
    static func getSubscriptionStatus(userID: String? = nil) async throws -> AIAvatarSubscriptionStatus {
        var params: [String: Any] = [:]
        if let userID = userID {
            params["user_id"] = userID
        }
        return try await API.getJSON("/ai/subscription/status", params: params.isEmpty ? nil : params)
    }
    
    // MARK: - Credits Check
    
    static func checkCredits(
        operationType: String,  // "text_to_image" | "image_to_image" | "avatar_batch"
        userID: String? = nil
    ) async throws -> AIAvatarCreditsCheck {
        var body: [String: Any] = [
            "operation_type": operationType
        ]
        if let userID = userID {
            body["user_id"] = userID
        }
        return try await API.postJSON("/ai/credits/check", body: body)
    }
    
    // MARK: - Credits Balance
    
    static func getCreditsBalance(userID: String? = nil) async throws -> AIAvatarCreditsBalance {
        var params: [String: Any] = [:]
        if let userID = userID {
            params["user_id"] = userID
        }
        return try await API.getJSON("/ai/credits/balance", params: params.isEmpty ? nil : params)
    }
    
    // MARK: - Activate Subscription
    
    static func activateSubscription(
        planType: String,  // "weekly" | "monthly" | "yearly"
        userID: String? = nil,
        expiresAt: String? = nil  // ISO date string, optional
    ) async throws -> AIAvatarSubscriptionActivate {
        var body: [String: Any] = [
            "plan_type": planType
        ]
        if let userID = userID {
            body["user_id"] = userID
        }
        if let expiresAt = expiresAt {
            body["expires_at"] = expiresAt
        }
        return try await API.postJSON("/ai/subscription/activate", body: body)
    }
    
    // MARK: - Cancel Subscription
    
    static func cancelSubscription(userID: String? = nil) async throws -> [String: Any] {
        var body: [String: Any] = [:]
        if let userID = userID {
            body["user_id"] = userID
        }
        return try await API.postJSONDict("/ai/subscription/cancel", body: body)
    }
}
