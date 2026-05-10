// 文件说明：认证领域模型，定义用户、设备、令牌和会话。
package auth

import "time"

// User 表示系统账号。
type User struct {
	ID           string
	Email        string
	DisplayName  string
	PasswordHash []byte
	CreatedAt    time.Time
}

// PublicUser 表示可以返回给客户端的用户信息。
type PublicUser struct {
	ID          string `json:"id"`
	Email       string `json:"email"`
	DisplayName string `json:"displayName"`
}

// Device 表示用户登录设备。
type Device struct {
	ID         string
	UserID     string
	DeviceName string
	Platform   string
	CreatedAt  time.Time
}

// PublicDevice 表示可以返回给客户端的设备信息。
type PublicDevice struct {
	ID         string `json:"id"`
	UserID     string `json:"userId"`
	DeviceName string `json:"deviceName"`
	Platform   string `json:"platform"`
}

// RefreshSession 表示刷新令牌会话。
type RefreshSession struct {
	TokenHash string
	UserID    string
	ExpiresAt time.Time
	Revoked   bool
}

// TokenPair 表示登录后的访问令牌和刷新令牌。
type TokenPair struct {
	AccessToken  string `json:"accessToken"`
	RefreshToken string `json:"refreshToken"`
}

// ToPublicUser 转换为客户端可见用户。
func ToPublicUser(user User) PublicUser {
	return PublicUser{ID: user.ID, Email: user.Email, DisplayName: user.DisplayName}
}

// ToPublicDevice 转换为客户端可见设备。
func ToPublicDevice(device Device) PublicDevice {
	return PublicDevice{ID: device.ID, UserID: device.UserID, DeviceName: device.DeviceName, Platform: device.Platform}
}
