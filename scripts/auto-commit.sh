#!/bin/bash
# ============================================
# xiao-hai 智能自动提交脚本
# 仅在检测到"重大变更"时自动提交，小修小改会跳过
# ============================================

REPO_DIR="$HOME/Projects/xiao-hai"
THRESHOLD_LINES=50       # 变更行数阈值（超过此值视为重大变更）
THRESHOLD_FILES=5         # 变更文件数阈值
COMMIT_MESSAGE_PREFIX="auto"

cd "$REPO_DIR" || exit 1

# 检查是否有未提交的变更
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M')] 没有变更，跳过"
    exit 0
fi

# 统计变更量
LINES_ADDED=$(git diff --numstat | awk '{sum+=$1} END {print sum+0}')
LINES_DELETED=$(git diff --numstat | awk '{sum+=$2} END {print sum+0}')
LINES_CHANGED=$((LINES_ADDED + LINES_DELETED))
FILES_MODIFIED=$(git diff --name-only | wc -l)
NEW_FILES=$(git ls-files --others --exclude-standard | wc -l)
DELETED_FILES=$(git diff --diff-filter=D --name-only | wc -l)

echo "============================================"
echo "[$(date '+%Y-%m-%d %H:%M')] 变更统计"
echo "  修改行数: $LINES_CHANGED"
echo "  修改文件: $FILES_MODIFIED"
echo "  新增文件: $NEW_FILES"
echo "  删除文件: $DELETED_FILES"
echo "  阈值: >${THRESHOLD_LINES} 行 或 >${THRESHOLD_FILES} 文件 或 有新增/删除文件"
echo "============================================"

# 判断是否为重大变更
IS_MAJOR=false
REASON=""

if [ "$LINES_CHANGED" -gt "$THRESHOLD_LINES" ]; then
    IS_MAJOR=true
    REASON="行数变更 $LINES_CHANGED > $THRESHOLD_LINES"
elif [ "$FILES_MODIFIED" -gt "$THRESHOLD_FILES" ]; then
    IS_MAJOR=true
    REASON="修改文件数 $FILES_MODIFIED > $THRESHOLD_FILES"
elif [ "$NEW_FILES" -gt 0 ]; then
    IS_MAJOR=true
    REASON="新增了 $NEW_FILES 个文件"
elif [ "$DELETED_FILES" -gt 0 ]; then
    IS_MAJOR=true
    REASON="删除了 $DELETED_FILES 个文件"
fi

if [ "$IS_MAJOR" = true ]; then
    echo "✅ 检测到重大变更 ($REASON)，自动提交中..."
    git add -A
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
    git commit -m "$COMMIT_MESSAGE_PREFIX: 重大变更 — $REASON ($TIMESTAMP)"

    # 尝试推送（如果有远程仓库）
    if git remote get-url origin &>/dev/null; then
        echo "📤 推送到远程仓库..."
        git push origin "$(git branch --show-current)" 2>&1 || echo "⚠️ 推送失败，请检查网络或远程设置"
    else
        echo "⚠️ 未设置远程仓库，跳过推送"
    fi
    echo "✅ 提交完成"
else
    echo "⏭️ 变更较小（行数=$LINES_CHANGED, 文件=$FILES_MODIFIED），跳过自动提交"
    echo "   提示：手动提交请运行 git add -A && git commit -m \"你的提交信息\""
fi
