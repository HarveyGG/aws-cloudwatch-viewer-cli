#!/bin/bash

set -e

TAG="$1"
MESSAGE="$2"

if [[ -z "$TAG" || -z "$MESSAGE" ]]; then
  echo "❌ Usage: ./release.sh v0.2.0 'your release message'"
  exit 1
fi

TAP_REPO_DIR="../homebrew-cwlogs"  # ⬅️ 你的 tap 仓库的本地路径（可按实际改）

echo "🚀 Releasing $TAG ..."

# 1. 打 tag + push
git tag -a "$TAG" -m "$MESSAGE"
git push origin "$TAG"

# 2. 下载 GitHub 自动生成的源码包
ARCHIVE_URL="https://github.com/HarveyGG/aws-cloudwatch-viewer-cli/archive/refs/tags/$TAG.tar.gz"
curl -L -o "$TAG.tar.gz" "$ARCHIVE_URL"

# 3. 计算 SHA256
SHA=$(shasum -a 256 "$TAG.tar.gz" | awk '{print $1}')
echo "✅ SHA256: $SHA"

# 4. 生成 .rb 文件内容
FORMULA_PATH="Formula/cwlogs.rb"
FULL_FORMULA_PATH="$TAP_REPO_DIR/$FORMULA_PATH"

mkdir -p "$(dirname "$FULL_FORMULA_PATH")"

cat > "$FULL_FORMULA_PATH" <<EOF
class Cwlogs < Formula
  desc "AWS CloudWatch Log Viewer with HTML output, alias & highlight support"
  homepage "https://github.com/HarveyGG/aws-cloudwatch-viewer-cli"
  url "https://github.com/HarveyGG/aws-cloudwatch-viewer-cli/archive/refs/tags/$TAG.tar.gz"
  sha256 "$SHA"
  version "${TAG#v}"

  def install
    bin.install "bin/cwlogs"
    bin.install "bin/cwlogs_real.sh"
  end
end
EOF

echo "✅ Formula updated at: $FORMULA_PATH"

# 5. 自动 commit 到 tap repo
cd "$TAP_REPO_DIR"
git add "$FORMULA_PATH"
git commit -m "Update cwlogs formula to $TAG"
git push origin main
cd "$OLDPWD"  # 返回原目录
rm -f "$TAG.tar.gz"

echo "🎉 Done! Tap repo updated. You can now run: brew upgrade cwlogs"
