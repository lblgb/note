// 文件说明：密码哈希和校验测试。
package auth

import "testing"

// TestHashAndComparePassword 验证密码哈希可以通过原密码校验。
func TestHashAndComparePassword(t *testing.T) {
	hash, err := HashPassword("pass123456")
	if err != nil {
		t.Fatalf("哈希密码失败：%v", err)
	}
	if len(hash) == 0 {
		t.Fatal("密码哈希不能为空")
	}
	if !ComparePassword(hash, "pass123456") {
		t.Fatal("原密码应通过校验")
	}
	if ComparePassword(hash, "wrong-password") {
		t.Fatal("错误密码不应通过校验")
	}
}
