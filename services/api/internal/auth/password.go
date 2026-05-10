// 文件说明：密码哈希和校验逻辑。
package auth

import "golang.org/x/crypto/bcrypt"

// HashPassword 生成安全密码哈希。
func HashPassword(password string) ([]byte, error) {
	return bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
}

// ComparePassword 校验明文密码是否匹配哈希。
func ComparePassword(hash []byte, password string) bool {
	return bcrypt.CompareHashAndPassword(hash, []byte(password)) == nil
}
