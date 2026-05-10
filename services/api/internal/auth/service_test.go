// 文件说明：认证服务和内存仓库测试。
package auth

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"
)

var errInjectedRefreshSave = errors.New("injected refresh save failure")

// TestMemoryRepositoryCreateAndFindUser 验证用户创建和邮箱查询。
func TestMemoryRepositoryCreateAndFindUser(t *testing.T) {
	repo := NewMemoryRepository()
	ctx := context.Background()
	user := User{ID: "usr_test", Email: "user@example.com", DisplayName: "用户", PasswordHash: []byte("hash")}

	if err := repo.CreateUser(ctx, user); err != nil {
		t.Fatalf("创建用户失败：%v", err)
	}

	got, err := repo.FindUserByEmail(ctx, "USER@example.com")
	if err != nil {
		t.Fatalf("查询用户失败：%v", err)
	}
	if got.ID != user.ID {
		t.Fatalf("期望用户 ID %q，实际为 %q", user.ID, got.ID)
	}
}

type failingRefreshRepository struct {
	sessions        map[string]RefreshSession
	failRefreshSave bool
}

func newFailingRefreshRepository(session RefreshSession) *failingRefreshRepository {
	return &failingRefreshRepository{
		sessions: map[string]RefreshSession{session.TokenHash: session},
	}
}

func (repo *failingRefreshRepository) CreateUser(ctx context.Context, user User) error {
	return nil
}

func (repo *failingRefreshRepository) FindUserByEmail(ctx context.Context, email string) (User, error) {
	return User{}, ErrUserNotFound
}

func (repo *failingRefreshRepository) FindUserByID(ctx context.Context, id string) (User, error) {
	return User{ID: id}, nil
}

func (repo *failingRefreshRepository) SaveRefreshSession(ctx context.Context, session RefreshSession) error {
	if repo.failRefreshSave {
		return errInjectedRefreshSave
	}
	repo.sessions[session.TokenHash] = session
	return nil
}

func (repo *failingRefreshRepository) FindRefreshSession(ctx context.Context, tokenHash string) (RefreshSession, error) {
	session, ok := repo.sessions[tokenHash]
	if !ok {
		return RefreshSession{}, ErrSessionNotFound
	}
	return session, nil
}

func (repo *failingRefreshRepository) RevokeRefreshSession(ctx context.Context, tokenHash string) error {
	session, ok := repo.sessions[tokenHash]
	if !ok {
		return ErrSessionNotFound
	}
	session.Revoked = true
	repo.sessions[tokenHash] = session
	return nil
}

func (repo *failingRefreshRepository) ConsumeRefreshSession(ctx context.Context, tokenHash string, now time.Time) (RefreshSession, error) {
	session, ok := repo.sessions[tokenHash]
	if !ok || session.Revoked || !now.Before(session.ExpiresAt) {
		return RefreshSession{}, ErrSessionNotFound
	}
	session.Revoked = true
	repo.sessions[tokenHash] = session
	return session, nil
}

func (repo *failingRefreshRepository) RotateRefreshSession(ctx context.Context, oldTokenHash string, newSession RefreshSession, now time.Time) (RefreshSession, error) {
	if repo.failRefreshSave {
		return RefreshSession{}, errInjectedRefreshSave
	}
	oldSession, ok := repo.sessions[oldTokenHash]
	if !ok || oldSession.Revoked || !now.Before(oldSession.ExpiresAt) {
		return RefreshSession{}, ErrSessionNotFound
	}
	newSession.UserID = oldSession.UserID
	oldSession.Revoked = true
	repo.sessions[oldTokenHash] = oldSession
	repo.sessions[newSession.TokenHash] = newSession
	return oldSession, nil
}

func (repo *failingRefreshRepository) SaveDevice(ctx context.Context, device Device) error {
	return nil
}

// TestServiceRefreshAllowsOnlyOneConcurrentRotation 验证同一个刷新令牌并发轮换时只有一次成功。
func TestServiceRefreshAllowsOnlyOneConcurrentRotation(t *testing.T) {
	service := NewService(NewMemoryRepository(), NewTokenManager([]byte("test-secret"), time.Hour, 24*time.Hour))
	ctx := context.Background()

	registered, err := service.Register(ctx, RegisterInput{Email: "user@example.com", Password: "pass123456", DisplayName: "用户"})
	if err != nil {
		t.Fatalf("注册失败：%v", err)
	}

	const goroutines = 32
	start := make(chan struct{})
	errs := make(chan error, goroutines)
	var wg sync.WaitGroup
	wg.Add(goroutines)
	for range goroutines {
		go func() {
			defer wg.Done()
			<-start
			_, err := service.Refresh(ctx, registered.RefreshToken)
			errs <- err
		}()
	}
	close(start)
	wg.Wait()
	close(errs)

	successes := 0
	invalidCredentials := 0
	for err := range errs {
		switch err {
		case nil:
			successes++
		case ErrInvalidCredentials:
			invalidCredentials++
		default:
			t.Fatalf("刷新返回了意外错误：%v", err)
		}
	}
	if successes != 1 || invalidCredentials != goroutines-1 {
		t.Fatalf("并发刷新应仅一次成功，实际成功 %d 次，凭据错误 %d 次", successes, invalidCredentials)
	}
}

// TestServiceRefreshKeepsOldTokenWhenReplacementSaveFails 验证新会话保存失败时旧刷新令牌仍可使用。
func TestServiceRefreshKeepsOldTokenWhenReplacementSaveFails(t *testing.T) {
	tokens := NewTokenManager([]byte("test-secret"), time.Hour, 24*time.Hour)
	refreshToken, refreshHash, expiresAt, err := tokens.IssueRefreshToken()
	if err != nil {
		t.Fatalf("签发刷新令牌失败：%v", err)
	}
	repo := newFailingRefreshRepository(RefreshSession{
		TokenHash: refreshHash,
		UserID:    "usr_test",
		ExpiresAt: expiresAt,
	})
	service := NewService(repo, tokens)

	repo.failRefreshSave = true
	if _, err := service.Refresh(context.Background(), refreshToken); err != errInjectedRefreshSave {
		t.Fatalf("期望替换会话保存失败，实际错误：%v", err)
	}
	if repo.sessions[refreshHash].Revoked {
		t.Fatal("替换会话保存失败时旧刷新令牌不应被撤销")
	}

	repo.failRefreshSave = false
	if _, err := service.Refresh(context.Background(), refreshToken); err != nil {
		t.Fatalf("旧刷新令牌应仍可再次刷新，实际错误：%v", err)
	}
	if !repo.sessions[refreshHash].Revoked {
		t.Fatal("成功刷新后旧刷新令牌应被撤销")
	}
}

// TestServiceRegisterDeviceRejectsUnknownUser 验证未知用户不能登记设备。
func TestServiceRegisterDeviceRejectsUnknownUser(t *testing.T) {
	repo := NewMemoryRepository()
	service := NewService(repo, NewTokenManager([]byte("test-secret"), time.Hour, 24*time.Hour))

	device, err := service.RegisterDevice(context.Background(), "usr_missing", DeviceInput{DeviceName: "Windows 主力机", Platform: "windows"})
	if err != ErrInvalidCredentials {
		t.Fatalf("期望 ErrInvalidCredentials，实际为 %v，设备为 %+v", err, device)
	}
	if len(repo.devices) != 0 {
		t.Fatalf("未知用户不应保存设备，实际保存 %d 个", len(repo.devices))
	}
}

// TestMemoryRepositoryRotateRefreshSessionExpiresAtBoundary 验证刷新会话在 now 等于 ExpiresAt 时已过期。
func TestMemoryRepositoryRotateRefreshSessionExpiresAtBoundary(t *testing.T) {
	repo := NewMemoryRepository()
	ctx := context.Background()
	now := time.Now()
	session := RefreshSession{TokenHash: "refresh_hash", UserID: "usr_test", ExpiresAt: now}
	newSession := RefreshSession{TokenHash: "new_refresh_hash", ExpiresAt: now.Add(time.Hour)}

	if err := repo.SaveRefreshSession(ctx, session); err != nil {
		t.Fatalf("保存刷新会话失败：%v", err)
	}
	if _, err := repo.RotateRefreshSession(ctx, session.TokenHash, newSession, now); err != ErrSessionNotFound {
		t.Fatalf("期望过期刷新会话不可轮换，实际错误：%v", err)
	}
	if _, exists := repo.sessions[newSession.TokenHash]; exists {
		t.Fatal("过期刷新会话轮换失败时不应保存新会话")
	}
}

// TestMemoryRepositoryRotateRefreshSessionRevokesOldAndSavesNew 验证刷新会话轮换在一次仓库调用内撤销旧会话并保存新会话。
func TestMemoryRepositoryRotateRefreshSessionRevokesOldAndSavesNew(t *testing.T) {
	repo := NewMemoryRepository()
	ctx := context.Background()
	now := time.Now()
	oldSession := RefreshSession{TokenHash: "old_refresh_hash", UserID: "usr_test", ExpiresAt: now.Add(time.Hour)}
	newSession := RefreshSession{TokenHash: "new_refresh_hash", ExpiresAt: now.Add(2 * time.Hour)}

	if err := repo.SaveRefreshSession(ctx, oldSession); err != nil {
		t.Fatalf("保存旧刷新会话失败：%v", err)
	}
	rotated, err := repo.RotateRefreshSession(ctx, oldSession.TokenHash, newSession, now)
	if err != nil {
		t.Fatalf("轮换刷新会话失败：%v", err)
	}
	if rotated.TokenHash != oldSession.TokenHash || rotated.UserID != oldSession.UserID {
		t.Fatalf("轮换应返回旧会话，实际为 %+v", rotated)
	}
	if !repo.sessions[oldSession.TokenHash].Revoked {
		t.Fatal("旧刷新会话应被撤销")
	}
	savedNew, exists := repo.sessions[newSession.TokenHash]
	if !exists {
		t.Fatal("新刷新会话应被保存")
	}
	if savedNew.UserID != oldSession.UserID {
		t.Fatalf("新刷新会话应继承用户 ID，实际为 %q", savedNew.UserID)
	}
}

// TestMemoryRepositoryRejectsDuplicateEmail 验证重复邮箱会被拒绝。
func TestMemoryRepositoryRejectsDuplicateEmail(t *testing.T) {
	repo := NewMemoryRepository()
	ctx := context.Background()
	user := User{ID: "usr_test", Email: "user@example.com", PasswordHash: []byte("hash")}

	if err := repo.CreateUser(ctx, user); err != nil {
		t.Fatalf("首次创建用户失败：%v", err)
	}
	if err := repo.CreateUser(ctx, User{ID: "usr_other", Email: "USER@example.com"}); err != ErrEmailExists {
		t.Fatalf("期望 ErrEmailExists，实际为 %v", err)
	}
}

// TestMemoryRepositoryClonesPasswordHashOnCreate 验证写入后外部哈希修改不会影响仓库状态。
func TestMemoryRepositoryClonesPasswordHashOnCreate(t *testing.T) {
	repo := NewMemoryRepository()
	ctx := context.Background()
	hash := []byte("hash")

	if err := repo.CreateUser(ctx, User{ID: "usr_test", Email: "user@example.com", PasswordHash: hash}); err != nil {
		t.Fatalf("创建用户失败：%v", err)
	}
	hash[0] = 'X'

	got, err := repo.FindUserByEmail(ctx, "user@example.com")
	if err != nil {
		t.Fatalf("查询用户失败：%v", err)
	}
	if string(got.PasswordHash) != "hash" {
		t.Fatalf("期望仓库哈希保持为 %q，实际为 %q", "hash", string(got.PasswordHash))
	}
}

// TestMemoryRepositoryClonesPasswordHashOnRead 验证读取结果的哈希修改不会影响仓库状态。
func TestMemoryRepositoryClonesPasswordHashOnRead(t *testing.T) {
	repo := NewMemoryRepository()
	ctx := context.Background()
	user := User{ID: "usr_test", Email: "user@example.com", PasswordHash: []byte("hash")}

	if err := repo.CreateUser(ctx, user); err != nil {
		t.Fatalf("创建用户失败：%v", err)
	}
	byEmail, err := repo.FindUserByEmail(ctx, "user@example.com")
	if err != nil {
		t.Fatalf("按邮箱查询用户失败：%v", err)
	}
	byEmail.PasswordHash[0] = 'X'

	byID, err := repo.FindUserByID(ctx, user.ID)
	if err != nil {
		t.Fatalf("按 ID 查询用户失败：%v", err)
	}
	if string(byID.PasswordHash) != "hash" {
		t.Fatalf("期望按邮箱读取结果不影响仓库哈希，实际为 %q", string(byID.PasswordHash))
	}
	byID.PasswordHash[0] = 'Y'

	got, err := repo.FindUserByEmail(ctx, "user@example.com")
	if err != nil {
		t.Fatalf("再次按邮箱查询用户失败：%v", err)
	}
	if string(got.PasswordHash) != "hash" {
		t.Fatalf("期望按 ID 读取结果不影响仓库哈希，实际为 %q", string(got.PasswordHash))
	}
}

// TestMemoryRepositoryRejectsDuplicateID 验证重复用户 ID 会被拒绝且邮箱索引不被破坏。
func TestMemoryRepositoryRejectsDuplicateID(t *testing.T) {
	repo := NewMemoryRepository()
	ctx := context.Background()
	first := User{ID: "usr_test", Email: "first@example.com", PasswordHash: []byte("hash")}
	second := User{ID: "usr_test", Email: "second@example.com", PasswordHash: []byte("other")}

	if err := repo.CreateUser(ctx, first); err != nil {
		t.Fatalf("首次创建用户失败：%v", err)
	}
	if err := repo.CreateUser(ctx, second); err != ErrUserIDExists {
		t.Fatalf("期望 ErrUserIDExists，实际为 %v", err)
	}

	got, err := repo.FindUserByEmail(ctx, "first@example.com")
	if err != nil {
		t.Fatalf("查询首个邮箱失败：%v", err)
	}
	if got.ID != first.ID || got.Email != first.Email {
		t.Fatalf("期望首个邮箱仍解析为首个用户，实际为 ID=%q Email=%q", got.ID, got.Email)
	}
	if _, err := repo.FindUserByEmail(ctx, "second@example.com"); err != ErrUserNotFound {
		t.Fatalf("期望第二个邮箱未写入索引，实际为 %v", err)
	}
}

// TestServiceRegisterLoginRefreshLogout 验证注册、登录、刷新和退出流程。
func TestServiceRegisterLoginRefreshLogout(t *testing.T) {
	service := NewService(NewMemoryRepository(), NewTokenManager([]byte("test-secret"), time.Hour, 24*time.Hour))
	ctx := context.Background()

	registered, err := service.Register(ctx, RegisterInput{Email: "user@example.com", Password: "pass123456", DisplayName: "用户"})
	if err != nil {
		t.Fatalf("注册失败：%v", err)
	}
	if registered.User.Email != "user@example.com" || registered.AccessToken == "" || registered.RefreshToken == "" {
		t.Fatalf("注册响应不完整：%+v", registered)
	}

	loggedIn, err := service.Login(ctx, LoginInput{Email: "user@example.com", Password: "pass123456"})
	if err != nil {
		t.Fatalf("登录失败：%v", err)
	}
	if loggedIn.AccessToken == "" || loggedIn.RefreshToken == "" {
		t.Fatalf("登录令牌不能为空：%+v", loggedIn)
	}

	refreshed, err := service.Refresh(ctx, loggedIn.RefreshToken)
	if err != nil {
		t.Fatalf("刷新失败：%v", err)
	}
	if refreshed.AccessToken == "" || refreshed.RefreshToken == "" || refreshed.RefreshToken == loggedIn.RefreshToken {
		t.Fatalf("刷新应返回新令牌：%+v", refreshed)
	}

	if err := service.Logout(ctx, refreshed.RefreshToken); err != nil {
		t.Fatalf("退出登录失败：%v", err)
	}
	if _, err := service.Refresh(ctx, refreshed.RefreshToken); err != ErrInvalidCredentials {
		t.Fatalf("已退出刷新令牌应失效，实际错误：%v", err)
	}
}

// TestServiceRegisterRejectsWeakPassword 验证弱密码被拒绝。
func TestServiceRegisterRejectsWeakPassword(t *testing.T) {
	service := NewService(NewMemoryRepository(), NewTokenManager([]byte("test-secret"), time.Hour, 24*time.Hour))

	_, err := service.Register(context.Background(), RegisterInput{Email: "user@example.com", Password: "short", DisplayName: "用户"})
	if err != ErrInvalidInput {
		t.Fatalf("期望 ErrInvalidInput，实际为 %v", err)
	}
}

// TestServiceRegisterDevice 验证设备登记。
func TestServiceRegisterDevice(t *testing.T) {
	service := NewService(NewMemoryRepository(), NewTokenManager([]byte("test-secret"), time.Hour, 24*time.Hour))
	ctx := context.Background()

	registered, err := service.Register(ctx, RegisterInput{Email: "user@example.com", Password: "pass123456", DisplayName: "用户"})
	if err != nil {
		t.Fatalf("注册失败：%v", err)
	}

	device, err := service.RegisterDevice(ctx, registered.User.ID, DeviceInput{DeviceName: "Windows 主力机", Platform: "windows"})
	if err != nil {
		t.Fatalf("设备登记失败：%v", err)
	}
	if device.UserID != registered.User.ID || device.Platform != "windows" {
		t.Fatalf("设备信息不匹配：%+v", device)
	}
}
